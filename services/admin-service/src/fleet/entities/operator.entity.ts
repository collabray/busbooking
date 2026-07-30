import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('operators')
export class Operator {
  @PrimaryGeneratedColumn('uuid')
  operator_id: string;

  @Column({ length: 150 })
  company_name: string;

  @Column({ length: 3 })
  country_code: string;

  @Column({ unique: true, length: 100 })
  contact_email: string;

  @Column({ unique: true, length: 20 })
  contact_phone: string;

  @Column('numeric', { precision: 5, scale: 2, default: 8.00 })
  commission_rate: number;

  @Column({ length: 20, default: 'ACTIVE' })
  status: string;

  @CreateDateColumn()
  created_at: Date;
}
