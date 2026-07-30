import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Schedule } from '../fleet/entities/schedule.entity';

@Injectable()
export class PricingService {
  constructor(
    @InjectRepository(Schedule) private scheduleRepo: Repository<Schedule>,
  ) {}

  async createRule(dto: any): Promise<any> {
    // Store pricing rule in Redis or DB
    return { rule_id: 'RULE_' + Date.now(), ...dto };
  }

  async calculatePrice(scheduleId: string, currency: string, demandFactor?: number): Promise<any> {
    const schedule = await this.scheduleRepo.findOne({ where: { schedule_id: scheduleId } });
    if (!schedule) return { error: 'Schedule not found' };

    const basePrice = parseFloat(schedule.base_price_usd as any);
    const fxRate = await this.getFXRate(currency);
    const surge = demandFactor || 1.0;
    const finalPrice = basePrice * fxRate * surge;

    return {
      schedule_id: scheduleId,
      base_price_usd: basePrice,
      currency,
      fx_rate: fxRate,
      surge_multiplier: surge,
      final_price: parseFloat(finalPrice.toFixed(2)),
    };
  }

  private async getFXRate(currency: string): Promise<number> {
    const rates: Record<string, number> = {
      KES: 130.5,
      UGX: 3750.0,
      TZS: 2550.0,
      USD: 1.0,
    };
    return rates[currency.toUpperCase()] || 1.0;
  }
}
