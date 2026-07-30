import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Brackets } from 'typeorm';
import { Bus } from './entities/bus.entity';
import { Operator } from './entities/operator.entity';
import { Route } from './entities/route.entity';
import { Schedule } from './entities/schedule.entity';
import { v4 as uuidv4 } from 'uuid';
import { 
  CreateBusDto, UpdateBusDto, 
  CreateOperatorDto, UpdateOperatorDto,
  CreateRouteDto, UpdateRouteDto,
  CreateScheduleDto, UpdateScheduleDto,
  CreateFareRuleDto, UpdateFareRuleDto,
  CreateSeatTemplateDto
} from './dto/fleet.dto';

@Injectable()
export class FleetService {
  constructor(
    @InjectRepository(Bus) private busRepo: Repository<Bus>,
    @InjectRepository(Operator) private operatorRepo: Repository<Operator>,
    @InjectRepository(Route) private routeRepo: Repository<Route>,
    @InjectRepository(Schedule) private scheduleRepo: Repository<Schedule>,
  ) {}

  // ===== OPERATORS =====
  async createOperator(dto: CreateOperatorDto): Promise<Operator> {
    const existing = await this.operatorRepo.findOne({
      where: [{ contact_email: dto.contact_email }, { contact_phone: dto.contact_phone }],
    });
    if (existing) {
      throw new ConflictException('Operator with this email or phone already exists');
    }

    const operator = this.operatorRepo.create({
      operator_id: uuidv4(),
      company_name: dto.company_name,
      legal_name: dto.legal_name || dto.company_name,
      registration_number: dto.registration_number,
      tax_id: dto.tax_id,
      country_code: dto.country_code,
      contact_email: dto.contact_email,
      contact_phone: dto.contact_phone,
      physical_address: dto.physical_address,
      commission_rate: dto.commission_rate ?? 8.00,
      settlement_account: dto.settlement_account || {},
      api_endpoint: dto.api_endpoint,
      api_key_hash: dto.api_key ? await this.hashApiKey(dto.api_key) : null,
      api_enabled: !!dto.api_endpoint,
      status: 'PENDING',
    });
    return this.operatorRepo.save(operator);
  }

  async getOperators(filters: any): Promise<{ data: Operator[]; total: number; page: number; limit: number }> {
    const qb = this.operatorRepo.createQueryBuilder('operator');

    if (filters.country) qb.andWhere('operator.country_code = :country', { country: filters.country.toUpperCase() });
    if (filters.status) qb.andWhere('operator.status = :status', { status: filters.status.toUpperCase() });

    const [data, total] = await qb
      .orderBy('operator.created_at', 'DESC')
      .skip((filters.page - 1) * filters.limit)
      .take(filters.limit)
      .getManyAndCount();

    return { data, total, page: filters.page, limit: filters.limit };
  }

  async getOperator(id: string): Promise<Operator> {
    const operator = await this.operatorRepo.findOne({ where: { operator_id: id } });
    if (!operator) throw new NotFoundException('Operator not found');
    return operator;
  }

  async updateOperator(id: string, dto: UpdateOperatorDto): Promise<Operator> {
    const operator = await this.getOperator(id);
    Object.assign(operator, dto);
    return this.operatorRepo.save(operator);
  }

  async updateOperatorStatus(id: string, status: string, reason?: string): Promise<Operator> {
    const operator = await this.getOperator(id);
    operator.status = status;
    return this.operatorRepo.save(operator);
  }

  async configureExternalApi(operatorId: string, config: any): Promise<any> {
    const operator = await this.getOperator(operatorId);
    operator.api_endpoint = config.base_url;
    operator.api_enabled = true;
    await this.operatorRepo.save(operator);
    return { message: 'External API configured', operator_id: operatorId };
  }

  async syncFaresFromExternal(operatorId: string): Promise<any> {
    // Production: Call external API, parse response, update fare_rules table
    const operator = await this.getOperator(operatorId);
    if (!operator.api_enabled || !operator.api_endpoint) {
      throw new BadRequestException('External API not configured for this operator');
    }
    return { 
      message: 'Fare sync initiated',
      operator_id: operatorId,
      status: 'PROCESSING',
      note: 'Implement actual HTTP call to operator API endpoint'
    };
  }

  // ===== BUSES =====
  async createBus(dto: CreateBusDto): Promise<Bus> {
    const operator = await this.getOperator(dto.operator_id);
    if (operator.status !== 'ACTIVE') {
      throw new BadRequestException('Cannot add bus to non-active operator');
    }

    const existing = await this.busRepo.findOne({ where: { registration_number: dto.registration_number } });
    if (existing) throw new ConflictException('Bus with this registration number already exists');

    const bus = this.busRepo.create({
      bus_id: uuidv4(),
      operator_id: dto.operator_id,
      registration_number: dto.registration_number,
      chassis_number: dto.chassis_number,
      engine_number: dto.engine_number,
      vin: dto.vin,
      capacity: dto.capacity,
      bus_type: dto.bus_type,
      seat_layout_json: dto.seat_layout_json || this.generateDefaultSeatLayout(dto.capacity),
      amenities: dto.amenities || { wifi: false, ac: false, charger: false, entertainment: false, refreshments: false, toilet: false },
      insurance_expiry: dto.insurance_expiry ? new Date(dto.insurance_expiry) : null,
      last_inspection_date: dto.last_inspection_date ? new Date(dto.last_inspection_date) : null,
      gps_unit_id: dto.gps_unit_id,
      status: 'OPERATIONAL',
      created_by: 'system', // Should come from auth context
    });
    return this.busRepo.save(bus);
  }

  async getBuses(filters: any): Promise<{ data: Bus[]; total: number; page: number; limit: number }> {
    const qb = this.busRepo.createQueryBuilder('bus').leftJoinAndSelect('bus.operator', 'operator');

    if (filters.operatorId) qb.andWhere('bus.operator_id = :operatorId', { operatorId: filters.operatorId });
    if (filters.status) qb.andWhere('bus.status = :status', { status: filters.status.toUpperCase() });
    if (filters.busType) qb.andWhere('bus.bus_type = :busType', { busType: filters.busType.toUpperCase() });

    const [data, total] = await qb
      .orderBy('bus.created_at', 'DESC')
      .skip((filters.page - 1) * filters.limit)
      .take(filters.limit)
      .getManyAndCount();

    return { data, total, page: filters.page, limit: filters.limit };
  }

  async getBus(id: string): Promise<Bus> {
    const bus = await this.busRepo.findOne({ where: { bus_id: id }, relations: ['operator'] });
    if (!bus) throw new NotFoundException('Bus not found');
    return bus;
  }

  async updateBus(id: string, dto: UpdateBusDto): Promise<Bus> {
    await this.busRepo.update(id, dto);
    return this.getBus(id);
  }

  async deleteBus(id: string): Promise<void> {
    const bus = await this.getBus(id);
    // Check for active schedules
    const activeSchedules = await this.scheduleRepo.count({ where: { bus_id: id, status: 'SCHEDULED' } });
    if (activeSchedules > 0) {
      throw new BadRequestException(`Cannot delete bus with ${activeSchedules} active schedules. Cancel schedules first.`);
    }
    await this.busRepo.delete(id);
  }

  async updateBusStatus(id: string, status: string, reason?: string): Promise<Bus> {
    const bus = await this.getBus(id);
    bus.status = status;
    return this.busRepo.save(bus);
  }

  // ===== ROUTES =====
  async createRoute(dto: CreateRouteDto): Promise<Route> {
    const isCrossBorder = dto.origin_country !== dto.destination_country;
    const route = this.routeRepo.create({
      route_id: uuidv4(),
      origin_city: dto.origin_city,
      origin_country: dto.origin_country,
      destination_city: dto.destination_city,
      destination_country: dto.destination_country,
      origin_coordinates: `(${dto.origin_lat},${dto.origin_lng})`,
      destination_coordinates: `(${dto.destination_lat},${dto.destination_lng})`,
      distance_km: dto.distance_km,
      waypoints_json: dto.waypoints ? JSON.stringify(dto.waypoints) : null,
      is_cross_border: isCrossBorder,
      kyc_required: isCrossBorder,
      status: 'ACTIVE',
    });
    return this.routeRepo.save(route);
  }

  async getRoutes(filters: any): Promise<{ data: Route[]; total: number; page: number; limit: number }> {
    const qb = this.routeRepo.createQueryBuilder('route');

    if (filters.origin) qb.andWhere('route.origin_city ILIKE :origin', { origin: `%${filters.origin}%` });
    if (filters.destination) qb.andWhere('route.destination_city ILIKE :dest', { dest: `%${filters.destination}%` });
    if (filters.isCrossBorder !== undefined) qb.andWhere('route.is_cross_border = :cb', { cb: filters.isCrossBorder });

    const [data, total] = await qb
      .orderBy('route.created_at', 'DESC')
      .skip((filters.page - 1) * filters.limit)
      .take(filters.limit)
      .getManyAndCount();

    return { data, total, page: filters.page, limit: filters.limit };
  }

  async getRoute(id: string): Promise<Route> {
    const route = await this.routeRepo.findOne({ where: { route_id: id } });
    if (!route) throw new NotFoundException('Route not found');
    return route;
  }

  async updateRoute(id: string, dto: UpdateRouteDto): Promise<Route> {
    const route = await this.getRoute(id);
    if (dto.origin_lat !== undefined && dto.origin_lng !== undefined) {
      route.origin_coordinates = `(${dto.origin_lat},${dto.origin_lng})`;
    }
    if (dto.destination_lat !== undefined && dto.destination_lng !== undefined) {
      route.destination_coordinates = `(${dto.destination_lat},${dto.destination_lng})`;
    }
    Object.assign(route, dto);
    return this.routeRepo.save(route);
  }

  async deleteRoute(id: string): Promise<void> {
    const route = await this.getRoute(id);
    const activeSchedules = await this.scheduleRepo.count({ where: { route_id: id, status: 'SCHEDULED' } });
    if (activeSchedules > 0) {
      throw new BadRequestException(`Cannot delete route with ${activeSchedules} active schedules.`);
    }
    await this.routeRepo.delete(id);
  }

  // ===== FARE RULES =====
  async createFareRule(dto: CreateFareRuleDto): Promise<any> {
    // In production: Insert into fare_rules table
    return {
      fare_rule_id: uuidv4(),
      ...dto,
      status: 'ACTIVE',
      created_at: new Date(),
    };
  }

  async getFareRules(filters: any): Promise<any[]> {
    // In production: Query fare_rules table
    return [];
  }

  async getFareRule(id: string): Promise<any> {
    // In production: Query fare_rules table
    return { fare_rule_id: id };
  }

  async updateFareRule(id: string, dto: UpdateFareRuleDto): Promise<any> {
    return { fare_rule_id: id, ...dto, updated_at: new Date() };
  }

  async deactivateFareRule(id: string): Promise<void> {
    // In production: Update status to INACTIVE
  }

  async calculateDynamicFare(dto: any): Promise<any> {
    // Fetch base fare from fare_rules
    // Apply surge based on demand
    // Apply peak hour multipliers
    // Apply weekend/holiday multipliers
    const basePrice = 3500;
    const surge = dto.demand_percent > 70 ? 1 + ((dto.demand_percent - 70) / 100) : 1.0;
    const finalPrice = Math.round(basePrice * surge);

    return {
      route_id: dto.route_id,
      bus_type: dto.bus_type,
      base_price: basePrice,
      surge_multiplier: parseFloat(surge.toFixed(2)),
      final_price: finalPrice,
      currency: dto.currency,
      breakdown: {
        base: basePrice,
        surge_amount: Math.round(basePrice * (surge - 1)),
        total: finalPrice,
      }
    };
  }

  // ===== SCHEDULES =====
  async createSchedule(dto: CreateScheduleDto): Promise<Schedule> {
    const bus = await this.getBus(dto.bus_id);
    const route = await this.getRoute(dto.route_id);

    if (bus.status !== 'OPERATIONAL') {
      throw new BadRequestException('Bus is not operational');
    }

    const schedule = this.scheduleRepo.create({
      schedule_id: uuidv4(),
      bus_id: dto.bus_id,
      route_id: dto.route_id,
      fare_rule_id: dto.fare_rule_id,
      departure_time: new Date(dto.departure_time),
      estimated_arrival_time: new Date(dto.estimated_arrival_time),
      base_price_usd: dto.base_price_usd,
      currency: dto.currency || 'USD',
      available_seats: bus.capacity,
      booked_seats: 0,
      status: 'SCHEDULED',
      created_by: 'system',
    });
    return this.scheduleRepo.save(schedule);
  }

  async getSchedules(filters: any): Promise<{ data: Schedule[]; total: number; page: number; limit: number }> {
    const qb = this.scheduleRepo.createQueryBuilder('schedule')
      .leftJoinAndSelect('schedule.bus', 'bus')
      .leftJoinAndSelect('schedule.route', 'route');

    if (filters.routeId) qb.andWhere('schedule.route_id = :routeId', { routeId: filters.routeId });
    if (filters.busId) qb.andWhere('schedule.bus_id = :busId', { busId: filters.busId });
    if (filters.status) qb.andWhere('schedule.status = :status', { status: filters.status.toUpperCase() });
    if (filters.fromDate) qb.andWhere('schedule.departure_time >= :from', { from: new Date(filters.fromDate) });
    if (filters.toDate) qb.andWhere('schedule.departure_time <= :to', { to: new Date(filters.toDate) });

    const [data, total] = await qb
      .orderBy('schedule.departure_time', 'ASC')
      .skip((filters.page - 1) * filters.limit)
      .take(filters.limit)
      .getManyAndCount();

    return { data, total, page: filters.page, limit: filters.limit };
  }

  async getSchedule(id: string): Promise<Schedule> {
    const schedule = await this.scheduleRepo.findOne({
      where: { schedule_id: id },
      relations: ['bus', 'route'],
    });
    if (!schedule) throw new NotFoundException('Schedule not found');
    return schedule;
  }

  async updateSchedule(id: string, dto: UpdateScheduleDto): Promise<Schedule> {
    const schedule = await this.getSchedule(id);
    if (dto.departure_time) schedule.departure_time = new Date(dto.departure_time);
    if (dto.estimated_arrival_time) schedule.estimated_arrival_time = new Date(dto.estimated_arrival_time);
    if (dto.base_price_usd) schedule.base_price_usd = dto.base_price_usd;
    if (dto.status) schedule.status = dto.status;
    return this.scheduleRepo.save(schedule);
  }

  async cancelSchedule(id: string, reason: string): Promise<Schedule> {
    const schedule = await this.getSchedule(id);
    schedule.status = 'CANCELLED';
    schedule.cancellation_reason = reason;
    return this.scheduleRepo.save(schedule);
  }

  // ===== SEAT TEMPLATES =====
  async createSeatTemplate(dto: CreateSeatTemplateDto): Promise<any> {
    return {
      template_id: uuidv4(),
      ...dto,
      created_at: new Date(),
    };
  }

  async getSeatTemplates(): Promise<any[]> {
    return [
      { template_id: 'tpl-2x2', name: '2x2 Standard', bus_type: 'STANDARD', rows: 10, columns: 4 },
      { template_id: 'tpl-2x1', name: '2x1 VIP', bus_type: 'VIP', rows: 10, columns: 3 },
      { template_id: 'tpl-2x3', name: '2x3 High Density', bus_type: 'STANDARD', rows: 12, columns: 5 },
    ];
  }

  // ===== HELPERS =====
  private generateDefaultSeatLayout(capacity: number): any {
    const seats = [];
    const cols = capacity <= 30 ? 3 : 4;
    const rows = Math.ceil(capacity / cols);
    let seatNum = 1;
    for (let r = 1; r <= rows; r++) {
      for (let c = 1; c <= cols; c++) {
        if (seatNum > capacity) break;
        seats.push({
          number: `${r}${String.fromCharCode(64 + c)}`,
          row: r,
          col: c,
          seat_type: c === 1 || c === cols ? 'WINDOW' : 'AISLE',
          attributes: [],
        });
        seatNum++;
      }
    }
    return { rows, columns: cols, seats };
  }

  private async hashApiKey(key: string): Promise<string> {
    // In production: Use bcrypt or Argon2
    return `hash_${Buffer.from(key).toString('base64')}`;
  }
}
