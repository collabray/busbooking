import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FleetController } from './fleet.controller';
import { FleetService } from './fleet.service';
import { Bus } from './entities/bus.entity';
import { Operator } from './entities/operator.entity';
import { Route } from './entities/route.entity';
import { Schedule } from './entities/schedule.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Bus, Operator, Route, Schedule])],
  controllers: [FleetController],
  providers: [FleetService],
})
export class FleetModule {}
