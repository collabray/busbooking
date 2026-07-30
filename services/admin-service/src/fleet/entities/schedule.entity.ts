import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn } from 'typeorm';
import { Bus } from './bus.entity';
import { Route } from './route.entity';

@Entity('schedules')
export class Schedule {
  @PrimaryGeneratedColumn('uuid')
  schedule_id: string;

  @Column('uuid')
  bus_id: string;

  @ManyToOne(() => Bus)
  @JoinColumn({ name: 'bus_id' })
  bus: Bus;

  @Column('uuid')
  route_id: string;

  @ManyToOne(() => Route)
  @JoinColumn({ name: 'route_id' })
  route: Route;

  @Column('timestamptz')
  departure_time: Date;

  @Column('timestamptz')
  estimated_arrival_time: Date;

  @Column('numeric', { precision: 10, scale: 2 })
  base_price_usd: number;

  @Column({ length: 20, default: 'SCHEDULED' })
  status: string;

  @CreateDateColumn()
  created_at: Date;
}
