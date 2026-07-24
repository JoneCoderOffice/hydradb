import { Controller, Get, Post, Body } from '@nestjs/common';
import { UsersService } from './users.service';
import { User } from './user.entity';
import { ApiTags, ApiOperation, ApiResponse, ApiBody } from '@nestjs/swagger';

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
    summary: 'Retrieve all users',
    description: 'Queries user records. This read operation is automatically routed to the Replica (Slave) database instance (via HAProxy port 5433).',
  })
  @ApiResponse({ status: 200, description: 'List of all users fetched from database.', type: [User] })
  async findAll(): Promise<User[]> {
    return this.usersService.findAll();
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
