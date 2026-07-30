import { Controller, Post, Get, Body, Param } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { PricingService } from './pricing.service';

@ApiTags('Dynamic Pricing')
@ApiBearerAuth()
@Controller('api/v1/admin/pricing')
export class PricingController {
  constructor(private readonly pricingService: PricingService) {}

  @Post('rules')
  createRule(@Body() dto: any) {
    return this.pricingService.createRule(dto);
  }

  @Get('calculate/:scheduleId')
  calculatePrice(@Param('scheduleId') scheduleId: string, @Body() dto: { currency: string; demand_factor?: number }) {
    return this.pricingService.calculatePrice(scheduleId, dto.currency, dto.demand_factor);
  }
}
