import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Configure template engine (EJS) and base views directory
  app.setBaseViewsDir(join(__dirname, 'views'));
  app.setViewEngine('ejs');

  const config = new DocumentBuilder()
    .setTitle('HydraDB - PostgreSQL Horizontal Scaling API')
    .setDescription(
      'REST API endpoints for the HydraDB project demonstrating TypeORM Primary/Replica connection routing, PgBouncer pooling, and HAProxy load balancing.'
    )
    .setVersion('1.0')
    .addTag('users')
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
