import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { createClient } from 'redis';
import { Pool } from 'pg';
import { v4 as uuidv4 } from 'uuid';
import winston from 'winston';
import Joi from 'joi';
import promClient from 'prom-client';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console()],
});

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(rateLimit({ windowMs: 60 * 1000, max: 100 }));

const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'secret',
  database: process.env.DB_NAME || 'omnibus_cargo',
  max: 50,
});

const redis = createClient({ url: process.env.REDIS_URL || 'redis://localhost:6379' });
redis.connect().catch(console.error);

// Cargo booking schema
const cargoBookingSchema = Joi.object({
  schedule_id: Joi.string().uuid().required(),
  sender_name: Joi.string().min(2).max(150).required(),
  sender_phone: Joi.string().pattern(/^\+?[1-9]\d{1,14}$/).required(),
  receiver_name: Joi.string().min(2).max(150).required(),
  receiver_phone: Joi.string().pattern(/^\+?[1-9]\d{1,14}$/).required(),
  receiver_station: Joi.string().min(2).max(100).required(),
  weight_kg: Joi.number().positive().max(500).required(),
  dimensions: Joi.object({
    length_cm: Joi.number().positive().required(),
    width_cm: Joi.number().positive().required(),
    height_cm: Joi.number().positive().required(),
  }).required(),
  description: Joi.string().max(500).required(),
  declared_value: Joi.number().positive().required(),
  currency: Joi.string().length(3).required(),
  fragile: Joi.boolean().default(false),
  perishable: Joi.boolean().default(false),
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'cargo-service' });
});

app.post('/api/v1/cargo/book', async (req, res) => {
  const { error, value } = cargoBookingSchema.validate(req.body);
  if (error) {
    return res.status(400).json({ error: error.details[0].message });
  }

  const cargoId = uuidv4();
  const trackingNumber = `CG${Date.now().toString(36).toUpperCase()}`;
  const volume = value.dimensions.length_cm * value.dimensions.width_cm * value.dimensions.height_cm;

  // Calculate cargo fee based on weight and volume
  const baseRate = value.weight_kg * 2.5; // $2.5 per kg base
  const volumeRate = (volume / 1000000) * 50; // $50 per cubic meter
  const cargoFee = Math.max(baseRate, volumeRate) + (value.fragile ? 5 : 0) + (value.perishable ? 10 : 0);

  try {
    await pool.query(
      `INSERT INTO cargo_bookings (
        cargo_id, tracking_number, schedule_id, sender_name, sender_phone,
        receiver_name, receiver_phone, receiver_station, weight_kg, volume_cm3,
        description, declared_value, currency, cargo_fee, fragile, perishable,
        status, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, 'PENDING', NOW())`,
      [
        cargoId, trackingNumber, value.schedule_id, value.sender_name, value.sender_phone,
        value.receiver_name, value.receiver_phone, value.receiver_station,
        value.weight_kg, volume, value.description, value.declared_value,
        value.currency, cargoFee, value.fragile, value.perishable,
      ]
    );

    // Reserve cargo space on schedule
    await pool.query(
      `UPDATE schedules SET cargo_reserved_kg = COALESCE(cargo_reserved_kg, 0) + $1 WHERE schedule_id = $2`,
      [value.weight_kg, value.schedule_id]
    );

    logger.info(`Cargo booked: ${trackingNumber} for schedule ${value.schedule_id}`);
    res.status(201).json({
      cargo_id: cargoId,
      tracking_number: trackingNumber,
      cargo_fee: cargoFee,
      currency: value.currency,
      status: 'PENDING',
      message: 'Cargo booking created. Proceed to payment.',
    });
  } catch (err) {
    logger.error('Cargo booking failed', err);
    res.status(500).json({ error: 'Failed to create cargo booking' });
  }
});

app.get('/api/v1/cargo/track/:trackingNumber', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT c.*, s.departure_time, s.estimated_arrival_time,
        r.origin_city, r.destination_city, b.registration_number
      FROM cargo_bookings c
      JOIN schedules s ON c.schedule_id = s.schedule_id
      JOIN routes r ON s.route_id = r.route_id
      JOIN buses b ON s.bus_id = b.bus_id
      WHERE c.tracking_number = $1`,
      [req.params.trackingNumber]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tracking number not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    logger.error('Tracking lookup failed', err);
    res.status(500).json({ error: 'Tracking lookup failed' });
  }
});

app.patch('/api/v1/cargo/:cargoId/status', async (req, res) => {
  const schema = Joi.object({
    status: Joi.string().valid('PENDING', 'CHECKED_IN', 'LOADED', 'IN_TRANSIT', 'ARRIVED', 'DELIVERED', 'RETURNED').required(),
    location: Joi.string().max(100).required(),
    notes: Joi.string().max(500).optional(),
  });
  const { error, value } = schema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  try {
    await pool.query(
      `UPDATE cargo_bookings SET status = $1, updated_at = NOW() WHERE cargo_id = $2`,
      [value.status, req.params.cargoId]
    );
    await pool.query(
      `INSERT INTO cargo_tracking_events (event_id, cargo_id, status, location, notes, created_at)
       VALUES ($1, $2, $3, $4, $5, NOW())`,
      [uuidv4(), req.params.cargoId, value.status, value.location, value.notes || '']
    );
    res.json({ message: 'Status updated', cargo_id: req.params.cargoId, status: value.status });
  } catch (err) {
    logger.error('Status update failed', err);
    res.status(500).json({ error: 'Update failed' });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  logger.info(`Cargo Service listening on port ${PORT}`);
});
