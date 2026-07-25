import { Controller, Get, Post, Body, Query } from '@nestjs/common';
import { UsersService } from './users.service';
import { User } from './user.entity';
import { ApiTags, ApiOperation, ApiResponse, ApiBody, ApiQuery } from '@nestjs/swagger';

@ApiTags('users')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  @ApiOperation({
    summary: 'Create a new user',
    description: 'Inserts a new user record. This write operation is automatically routed to the Primary (Master) database instance (via HAProxy port 5432).',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        name: { type: 'string', example: 'Alice Smith' },
        email: { type: 'string', example: 'alice@example.com' },
      },
    },
  })
  @ApiResponse({ status: 201, description: 'User record created successfully.', type: User })
  async create(@Body() createUserDto: { name: string; email: string }): Promise<User> {
    return this.usersService.create(createUserDto.name, createUserDto.email);
  }

  @Get()
  @ApiOperation({
    summary: 'Retrieve users with pagination',
    description: 'Queries user records with pagination. This read operation is automatically routed to the Replica (Slave) database instance (via HAProxy port 5433).',
  })
  @ApiQuery({ name: 'page', required: false, type: Number, description: 'Page number (default: 1)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Number of items per page (default: 10)' })
  @ApiResponse({ status: 200, description: 'Paginated list of users fetched from database.' })
  async findAll(
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '10',
  ): Promise<{ data: User[]; total: number; page: number; limit: number }> {
    const pageNum = parseInt(page, 10) || 1;
    const limitNum = parseInt(limit, 10) || 10;
    return this.usersService.findAll(pageNum, limitNum);
  }

  @Get('db-info')
  @ApiOperation({
    summary: 'Get database connection routing details',
    description: 'Queries both master and slave instances separately using independent query runners to verify IP addresses and standby/replica flags.',
  })
  @ApiResponse({ status: 200, description: 'Database diagnostic details returned.' })
  async getDbInfo() {
    return this.usersService.getDbInfo();
  }
}
