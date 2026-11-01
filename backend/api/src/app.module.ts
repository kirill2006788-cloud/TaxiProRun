import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { AuthController } from './auth.controller';
import { OtpService } from './otp.service';
import { RedisService } from './redis.service';
import { SmsService } from './sms.service';
import { EventsGateway } from './events.gateway';
import { OrdersController } from './orders.controller';
import { AdminController } from './admin.controller';
import { TariffsController } from './tariffs.controller';
import { OrdersService } from './orders.service';
import { DriversService } from './drivers.service';
import { DriversController } from './drivers.controller';
import { ClientsController } from './clients.controller';
import { BroadcastsController } from './broadcasts.controller';
import { TaxiController } from './taxi.controller';
import { PushService } from './push.service';
import { SupportController } from './support.controller';
import { PaymentsController } from './payments.controller';
import { StoreModuleService } from './store/store.module';
import { PaymentAuditService } from './payments/audit.service';

@Module({
  imports: [],
  controllers: [
    HealthController,
    AuthController,
    OrdersController,
    AdminController,
    TariffsController,
    DriversController,
    ClientsController,
    BroadcastsController,
    TaxiController,
    SupportController,
    PaymentsController,
  ],
  providers: [
    RedisService,
    StoreModuleService,
    OtpService,
    SmsService,
    PushService,
    PaymentAuditService,
    OrdersService,
    DriversService,
    EventsGateway,
  ],
})
export class AppModule {}
