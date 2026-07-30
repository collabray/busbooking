import { 
  IsString, IsUUID, IsInt, IsNumber, IsBoolean, IsOptional, IsJSON, 
  IsIn, IsEmail, IsUrl, Min, Max, MaxLength, IsDateString, IsObject,
  ValidateNested, ArrayMinSize, IsNotEmpty
} from 'class-validator';
import { Type } from 'class-transformer';

// ===== OPERATOR DTOs =====
export class CreateOperatorDto {
  @IsString() @MaxLength(150) @IsNotEmpty() company_name: string;
  @IsString() @MaxLength(150) @IsOptional() legal_name?: string;
  @IsString() @MaxLength(50) @IsOptional() registration_number?: string;
  @IsString() @MaxLength(50) @IsOptional() tax_id?: string;
  @IsString() @IsIn(['KEN', 'UGA', 'TZA', 'RWA', 'BDI', 'SSD']) country_code: string;
  @IsEmail() @MaxLength(100) contact_email: string;
  @IsString() @MaxLength(20) contact_phone: string;
  @IsString() @IsOptional() physical_address?: string;
  @IsNumber() @Min(0) @Max(50) @IsOptional() commission_rate?: number;
  @IsObject() @IsOptional() settlement_account?: any;
  @IsUrl() @IsOptional() api_endpoint?: string;
  @IsString() @IsOptional() api_key?: string;
}

export class UpdateOperatorDto {
  @IsString() @MaxLength(150) @IsOptional() company_name?: string;
  @IsString() @MaxLength(150) @IsOptional() legal_name?: string;
  @IsString() @MaxLength(50) @IsOptional() registration_number?: string;
  @IsString() @MaxLength(50) @IsOptional() tax_id?: string;
  @IsEmail() @MaxLength(100) @IsOptional() contact_email?: string;
  @IsString() @MaxLength(20) @IsOptional() contact_phone?: string;
  @IsString() @IsOptional() physical_address?: string;
  @IsNumber() @Min(0) @Max(50) @IsOptional() commission_rate?: number;
  @IsObject() @IsOptional() settlement_account?: any;
}

// ===== BUS DTOs =====
export class CreateBusDto {
  @IsUUID() operator_id: string;
  @IsString() @MaxLength(30) @IsNotEmpty() registration_number: string;
  @IsString() @MaxLength(50) @IsOptional() chassis_number?: string;
  @IsString() @MaxLength(50) @IsOptional() engine_number?: string;
  @IsString() @MaxLength(50) @IsOptional() vin?: string;
  @IsInt() @Min(1) @Max(80) capacity: number;
  @IsString() @IsIn(['STANDARD', 'EXECUTIVE', 'VIP', 'LUXURY', 'DOUBLE_DECKER']) bus_type: string;
  @IsObject() @IsOptional() seat_layout_json?: any;
  @IsObject() @IsOptional() amenities?: any;
  @IsDateString() @IsOptional() insurance_expiry?: string;
  @IsDateString() @IsOptional() last_inspection_date?: string;
  @IsString() @MaxLength(50) @IsOptional() gps_unit_id?: string;
}

export class UpdateBusDto {
  @IsString() @MaxLength(30) @IsOptional() registration_number?: string;
  @IsString() @MaxLength(50) @IsOptional() chassis_number?: string;
  @IsInt() @Min(1) @Max(80) @IsOptional() capacity?: number;
  @IsString() @IsIn(['STANDARD', 'EXECUTIVE', 'VIP', 'LUXURY', 'DOUBLE_DECKER']) @IsOptional() bus_type?: string;
  @IsObject() @IsOptional() seat_layout_json?: any;
  @IsObject() @IsOptional() amenities?: any;
  @IsDateString() @IsOptional() insurance_expiry?: string;
  @IsString() @MaxLength(50) @IsOptional() gps_unit_id?: string;
}

// ===== ROUTE DTOs =====
export class CreateRouteDto {
  @IsString() @MaxLength(100) @IsNotEmpty() origin_city: string;
  @IsString() @IsIn(['KEN', 'UGA', 'TZA', 'RWA', 'BDI', 'SSD']) origin_country: string;
  @IsString() @MaxLength(100) @IsNotEmpty() destination_city: string;
  @IsString() @IsIn(['KEN', 'UGA', 'TZA', 'RWA', 'BDI', 'SSD']) destination_country: string;
  @IsNumber() origin_lat: number;
  @IsNumber() origin_lng: number;
  @IsNumber() destination_lat: number;
  @IsNumber() destination_lng: number;
  @IsNumber() @IsOptional() distance_km?: number;
  @IsObject() @IsOptional() waypoints?: any[];
  @IsBoolean() @IsOptional() is_cross_border?: boolean;
}

export class UpdateRouteDto {
  @IsString() @MaxLength(100) @IsOptional() origin_city?: string;
  @IsString() @MaxLength(100) @IsOptional() destination_city?: string;
  @IsNumber() @IsOptional() origin_lat?: number;
  @IsNumber() @IsOptional() origin_lng?: number;
  @IsNumber() @IsOptional() destination_lat?: number;
  @IsNumber() @IsOptional() destination_lng?: number;
  @IsObject() @IsOptional() waypoints?: any[];
  @IsBoolean() @IsOptional() is_cross_border?: boolean;
  @IsString() @IsIn(['ACTIVE', 'INACTIVE']) @IsOptional() status?: string;
}

// ===== FARE RULE DTOs =====
export class CreateFareRuleDto {
  @IsUUID() route_id: string;
  @IsString() @IsIn(['STANDARD', 'EXECUTIVE', 'VIP', 'LUXURY', 'DOUBLE_DECKER']) bus_type: string;
  @IsNumber() @Min(0) base_price_kes: number;
  @IsNumber() @Min(0) base_price_ugx: number;
  @IsNumber() @Min(0) base_price_tzs: number;
  @IsNumber() @Min(0) base_price_usd: number;
  @IsNumber() @Min(1.0) @IsOptional() surge_multiplier_min?: number;
  @IsNumber() @Min(1.0) @IsOptional() surge_multiplier_max?: number;
  @IsInt() @Min(0) @Max(100) @IsOptional() demand_threshold?: number;
  @IsObject() @IsOptional() peak_hours?: any;
  @IsNumber() @Min(0) @IsOptional() weekend_multiplier?: number;
  @IsNumber() @Min(0) @IsOptional() holiday_multiplier?: number;
  @IsNumber() @Min(0) @Max(100) @IsOptional() child_discount_percent?: number;
  @IsNumber() @Min(0) @Max(100) @IsOptional() senior_discount_percent?: number;
  @IsDateString() @IsOptional() effective_from?: string;
  @IsDateString() @IsOptional() effective_to?: string;
}

export class UpdateFareRuleDto {
  @IsNumber() @Min(0) @IsOptional() base_price_kes?: number;
  @IsNumber() @Min(0) @IsOptional() base_price_ugx?: number;
  @IsNumber() @Min(0) @IsOptional() base_price_tzs?: number;
  @IsNumber() @Min(0) @IsOptional() base_price_usd?: number;
  @IsNumber() @Min(1.0) @IsOptional() surge_multiplier_min?: number;
  @IsNumber() @Min(1.0) @IsOptional() surge_multiplier_max?: number;
  @IsInt() @Min(0) @Max(100) @IsOptional() demand_threshold?: number;
  @IsObject() @IsOptional() peak_hours?: any;
  @IsNumber() @Min(0) @IsOptional() weekend_multiplier?: number;
  @IsNumber() @Min(0) @IsOptional() holiday_multiplier?: number;
  @IsDateString() @IsOptional() effective_to?: string;
  @IsString() @IsIn(['ACTIVE', 'INACTIVE']) @IsOptional() status?: string;
}

// ===== SCHEDULE DTOs =====
export class CreateScheduleDto {
  @IsUUID() bus_id: string;
  @IsUUID() route_id: string;
  @IsUUID() @IsOptional() fare_rule_id?: string;
  @IsDateString() departure_time: string;
  @IsDateString() estimated_arrival_time: string;
  @IsNumber() @Min(0) base_price_usd: number;
  @IsString() @MaxLength(3) @IsOptional() currency?: string;
}

export class UpdateScheduleDto {
  @IsDateString() @IsOptional() departure_time?: string;
  @IsDateString() @IsOptional() estimated_arrival_time?: string;
  @IsNumber() @Min(0) @IsOptional() base_price_usd?: number;
  @IsString() @MaxLength(3) @IsOptional() currency?: string;
  @IsString() @IsIn(['SCHEDULED', 'BOARDING', 'DEPARTED', 'ARRIVED', 'CANCELLED', 'DELAYED']) @IsOptional() status?: string;
}

// ===== SEAT TEMPLATE DTOs =====
export class CreateSeatTemplateDto {
  @IsString() @MaxLength(50) @IsNotEmpty() name: string;
  @IsString() @IsOptional() description?: string;
  @IsString() @IsIn(['STANDARD', 'EXECUTIVE', 'VIP', 'LUXURY', 'DOUBLE_DECKER']) bus_type: string;
  @IsInt() @Min(1) rows: number;
  @IsInt() @Min(1) columns: number;
  @IsObject() layout_json: any;
}
