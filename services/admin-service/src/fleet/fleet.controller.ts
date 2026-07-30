import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, ParseUUIDPipe, HttpStatus, HttpCode } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { FleetService } from './fleet.service';
import { 
  CreateOperatorDto, UpdateOperatorDto, 
  CreateBusDto, UpdateBusDto, 
  CreateRouteDto, UpdateRouteDto,
  CreateScheduleDto, UpdateScheduleDto,
  CreateFareRuleDto, UpdateFareRuleDto,
  CreateSeatTemplateDto
} from './dto/fleet.dto';
import { AdminAuthGuard } from '../auth/admin-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@ApiTags('Fleet Management')
@ApiBearerAuth()
@UseGuards(AdminAuthGuard, RolesGuard)
@Controller('api/v1/admin/fleet')
export class FleetController {
  constructor(private readonly fleetService: FleetService) {}

  // ===== OPERATORS =====
  @ApiOperation({ summary: 'Register new bus company/operator' })
  @ApiResponse({ status: 201, description: 'Operator created successfully' })
  @ApiResponse({ status: 409, description: 'Email or phone already exists' })
  @Post('operators')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  @HttpCode(HttpStatus.CREATED)
  async createOperator(@Body() dto: CreateOperatorDto) {
    return this.fleetService.createOperator(dto);
  }

  @ApiOperation({ summary: 'List all registered operators' })
  @Get('operators')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getOperators(
    @Query('country') country?: string,
    @Query('status') status?: string,
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 50,
  ) {
    return this.fleetService.getOperators({ country, status, page, limit });
  }

  @ApiOperation({ summary: 'Get operator by ID' })
  @Get('operators/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getOperator(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.getOperator(id);
  }

  @ApiOperation({ summary: 'Update operator details' })
  @Put('operators/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async updateOperator(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateOperatorDto) {
    return this.fleetService.updateOperator(id, dto);
  }

  @ApiOperation({ summary: 'Suspend or blacklist operator' })
  @Put('operators/:id/status')
  @Roles('SUPER_ADMIN')
  async updateOperatorStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body('status') status: string,
    @Body('reason') reason?: string,
  ) {
    return this.fleetService.updateOperatorStatus(id, status, reason);
  }

  @ApiOperation({ summary: 'Configure external API for fare fetching' })
  @Post('operators/:id/api-config')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async configureExternalApi(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() config: any,
  ) {
    return this.fleetService.configureExternalApi(id, config);
  }

  @ApiOperation({ summary: 'Trigger manual fare sync from external API' })
  @Post('operators/:id/sync-fares')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async syncFares(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.syncFaresFromExternal(id);
  }

  // ===== BUSES =====
  @ApiOperation({ summary: 'Add new bus to fleet' })
  @Post('buses')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  @HttpCode(HttpStatus.CREATED)
  async createBus(@Body() dto: CreateBusDto) {
    return this.fleetService.createBus(dto);
  }

  @ApiOperation({ summary: 'List all buses' })
  @Get('buses')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getBuses(
    @Query('operator_id') operatorId?: string,
    @Query('status') status?: string,
    @Query('bus_type') busType?: string,
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 50,
  ) {
    return this.fleetService.getBuses({ operatorId, status, busType, page, limit });
  }

  @ApiOperation({ summary: 'Get bus by ID' })
  @Get('buses/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getBus(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.getBus(id);
  }

  @ApiOperation({ summary: 'Update bus details' })
  @Put('buses/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async updateBus(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateBusDto) {
    return this.fleetService.updateBus(id, dto);
  }

  @ApiOperation({ summary: 'Delete bus from fleet' })
  @Delete('buses/:id')
  @Roles('SUPER_ADMIN')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteBus(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.deleteBus(id);
  }

  @ApiOperation({ summary: 'Update bus status (operational/maintenance/retired)' })
  @Put('buses/:id/status')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async updateBusStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body('status') status: string,
    @Body('reason') reason?: string,
  ) {
    return this.fleetService.updateBusStatus(id, status, reason);
  }

  // ===== ROUTES =====
  @ApiOperation({ summary: 'Create new route' })
  @Post('routes')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  @HttpCode(HttpStatus.CREATED)
  async createRoute(@Body() dto: CreateRouteDto) {
    return this.fleetService.createRoute(dto);
  }

  @ApiOperation({ summary: 'List all routes' })
  @Get('routes')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getRoutes(
    @Query('origin') origin?: string,
    @Query('destination') destination?: string,
    @Query('is_cross_border') isCrossBorder?: boolean,
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 50,
  ) {
    return this.fleetService.getRoutes({ origin, destination, isCrossBorder, page, limit });
  }

  @ApiOperation({ summary: 'Get route by ID' })
  @Get('routes/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async getRoute(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.getRoute(id);
  }

  @ApiOperation({ summary: 'Update route' })
  @Put('routes/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async updateRoute(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateRouteDto) {
    return this.fleetService.updateRoute(id, dto);
  }

  @ApiOperation({ summary: 'Delete route' })
  @Delete('routes/:id')
  @Roles('SUPER_ADMIN')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteRoute(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.deleteRoute(id);
  }

  // ===== FARE RULES =====
  @ApiOperation({ summary: 'Create fare rule for a route' })
  @Post('fare-rules')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  @HttpCode(HttpStatus.CREATED)
  async createFareRule(@Body() dto: CreateFareRuleDto) {
    return this.fleetService.createFareRule(dto);
  }

  @ApiOperation({ summary: 'List fare rules' })
  @Get('fare-rules')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getFareRules(
    @Query('route_id') routeId?: string,
    @Query('bus_type') busType?: string,
    @Query('status') status?: string,
  ) {
    return this.fleetService.getFareRules({ routeId, busType, status });
  }

  @ApiOperation({ summary: 'Get fare rule by ID' })
  @Get('fare-rules/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getFareRule(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.getFareRule(id);
  }

  @ApiOperation({ summary: 'Update fare rule' })
  @Put('fare-rules/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async updateFareRule(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateFareRuleDto) {
    return this.fleetService.updateFareRule(id, dto);
  }

  @ApiOperation({ summary: 'Deactivate fare rule' })
  @Delete('fare-rules/:id')
  @Roles('SUPER_ADMIN', 'FINANCE_ADMIN')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteFareRule(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.deactivateFareRule(id);
  }

  @ApiOperation({ summary: 'Calculate dynamic fare for a schedule' })
  @Post('fare-rules/calculate')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async calculateFare(@Body() dto: { route_id: string; bus_type: string; departure_time: string; demand_percent: number; currency: string }) {
    return this.fleetService.calculateDynamicFare(dto);
  }

  // ===== SCHEDULES =====
  @ApiOperation({ summary: 'Create schedule/trip' })
  @Post('schedules')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  @HttpCode(HttpStatus.CREATED)
  async createSchedule(@Body() dto: CreateScheduleDto) {
    return this.fleetService.createSchedule(dto);
  }

  @ApiOperation({ summary: 'List schedules' })
  @Get('schedules')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getSchedules(
    @Query('route_id') routeId?: string,
    @Query('bus_id') busId?: string,
    @Query('from_date') fromDate?: string,
    @Query('to_date') toDate?: string,
    @Query('status') status?: string,
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 50,
  ) {
    return this.fleetService.getSchedules({ routeId, busId, fromDate, toDate, status, page, limit });
  }

  @ApiOperation({ summary: 'Get schedule by ID' })
  @Get('schedules/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN')
  async getSchedule(@Param('id', ParseUUIDPipe) id: string) {
    return this.fleetService.getSchedule(id);
  }

  @ApiOperation({ summary: 'Update schedule' })
  @Put('schedules/:id')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async updateSchedule(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateScheduleDto) {
    return this.fleetService.updateSchedule(id, dto);
  }

  @ApiOperation({ summary: 'Cancel schedule' })
  @Put('schedules/:id/cancel')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async cancelSchedule(
    @Param('id', ParseUUIDPipe) id: string,
    @Body('reason') reason: string,
  ) {
    return this.fleetService.cancelSchedule(id, reason);
  }

  // ===== SEAT TEMPLATES =====
  @ApiOperation({ summary: 'Create seat layout template' })
  @Post('seat-templates')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async createSeatTemplate(@Body() dto: CreateSeatTemplateDto) {
    return this.fleetService.createSeatTemplate(dto);
  }

  @ApiOperation({ summary: 'List seat layout templates' })
  @Get('seat-templates')
  @Roles('SUPER_ADMIN', 'OPERATIONS_MANAGER')
  async getSeatTemplates() {
    return this.fleetService.getSeatTemplates();
  }
}
