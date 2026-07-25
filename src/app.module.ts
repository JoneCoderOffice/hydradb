import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        replication: {
          master: {
            host: configService.get<string>('DB_HOST', 'localhost'),
            port: Number(
              configService.get<string | number>('DB_PORT_WRITE', 5432),
            ),
            username: configService.get<string>('DB_USERNAME', 'hydra_user'),
            password: configService.get<string>('DB_PASSWORD', 'hydra_pwd'),
            database: configService.get<string>('DB_DATABASE', 'hydra_db'),
          },
          slaves: [
            {
              host: configService.get<string>('DB_HOST', 'localhost'),
              port: Number(
                configService.get<string | number>('DB_PORT_READ', 5433),
              ),
              username: configService.get<string>('DB_USERNAME', 'hydra_user'),
              password: configService.get<string>('DB_PASSWORD', 'hydra_pwd'),
              database: configService.get<string>('DB_DATABASE', 'hydra_db'),
            },
          ],
        },
        autoLoadEntities: true,
        synchronize: true,
        logging: true,
      }),
    }),
    UsersModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
