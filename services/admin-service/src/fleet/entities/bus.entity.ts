import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { Operator } from './operator.entity';

@Entity('buses')
export class Bus {
  @PrimaryGeneratedColumn('uuid')
  bus_id: string;

  @Column('uuid')
  operator_id: string;

  @ManyToOne(() => Operator)
  @JoinColumn({ name: 'operator_id' })
  operator: Operator;

  @Column({ unique: true, length: 30 })
  registration_number: string;

  @Column({ unique: true, length: 50, nullable: true })
  chassis_number: string;

  @Column('int')
  capacity: number;

  @Column({ length: 30 })
  bus_type: string;

  @Column('jsonb')
  seat_layout_json: any;

  @Column('jsonb', { default: { wifi: false, ac: false, charger: false } })
  amenities: any;

  @Column({ length: 20, default: 'OPERATIONAL' })
  status: string;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
