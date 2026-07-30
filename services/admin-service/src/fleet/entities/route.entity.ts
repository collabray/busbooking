import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('routes')
export class Route {
  @PrimaryGeneratedColumn('uuid')
  route_id: string;

  @Column({ length: 100 })
  origin_city: string;

  @Column({ length: 100 })
  destination_city: string;

  @Column('point')
  origin_coordinates: string;

  @Column('point')
  destination_coordinates: string;

  @Column('jsonb', { nullable: true })
  waypoints_json: any;

  @Column({ default: false })
  is_cross_border: boolean;

  @CreateDateColumn()
  created_at: Date;
}
