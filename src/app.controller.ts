import { Controller, Get, StreamableFile, Render, Header } from '@nestjs/common';
import { AppService } from './app.service';
import { createReadStream } from 'fs';
import { join } from 'path';
import { ApiExcludeController } from '@nestjs/swagger';

@ApiExcludeController()
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @Render('index')
  getHome() {
    return {};
  }

  @Get('hydradb.drawio.svg')
  @Header('Content-Type', 'image/svg+xml')
  getSvg(): StreamableFile {
    const svgPath = join(__dirname, 'assets', 'hydradb.drawio.svg');
    const file = createReadStream(svgPath);
    return new StreamableFile(file);
  }
}
