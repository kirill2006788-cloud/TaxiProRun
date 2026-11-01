import { Body, Controller, Get, Post } from '@nestjs/common';

import { RedisService } from './redis.service';

import {

  DEFAULT_TAXI_TARIFFS,

  computeTaxiQuote,

  type TaxiTariff,

} from './pricing/taxi-pricing';



@Controller('taxi')

export class TaxiController {

  constructor(private readonly redis: RedisService) {}



  @Get('tariffs')

  async list() {

    return { ok: true, tariffs: await this.loadTariffs() };

  }



  @Post('quote')

  async quote(@Body() body: Record<string, unknown>) {

    const tariffs = await this.loadTariffs();

    const tariffId = String(body?.tariffId || '').trim();

    const tariff =

      tariffs.find((t) => String(t?.id || '') === tariffId) || tariffs[0];

    const stopsRaw = body?.stopsCount ?? body?.stops;

    const stopsCount = Array.isArray(stopsRaw)

      ? stopsRaw.length

      : Number(stopsRaw || 0);

    const result = computeTaxiQuote(tariff, {

      routeDistanceMeters: Number(body?.routeDistanceMeters || 0) || undefined,

      from: body?.from as { lat: number; lng: number } | undefined,

      to: body?.to as { lat: number; lng: number } | undefined,

      stopsCount: Number.isFinite(stopsCount) ? stopsCount : 0,

      withKids: body?.withKids === true,

      withPets: body?.withPets === true,

      airConditioning: body?.airConditioning === true,

      discountPercent: Number(body?.discountPercent || 0),

    });

    return {

      ok: true,

      priceFrom: result.priceFrom,

      tariffName: result.tariffName,

      routeDistanceMeters: Math.round(result.distanceKm * 1000),

      source: 'server',

    };

  }



  private async loadTariffs(): Promise<TaxiTariff[]> {

    const raw = await this.redis.client.get('taxi_tariffs:list');

    if (raw) {

      try {

        const parsed = JSON.parse(raw);

        if (Array.isArray(parsed) && parsed.length) return parsed;

      } catch {

        // fall through

      }

    }

    return DEFAULT_TAXI_TARIFFS;

  }

}


