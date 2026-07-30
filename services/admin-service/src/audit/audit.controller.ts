import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { AuditService } from './audit.service';

@ApiTags('Audit & Compliance')
@ApiBearerAuth()
@Controller('api/v1/admin/audit')
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get('logs')
  getAuditLogs(
    @Query('admin_id') adminId?: string,
    @Query('action') action?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.auditService.getLogs(adminId, action, from, to);
  }
}
