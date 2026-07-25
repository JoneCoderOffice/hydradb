import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async create(name: string, email: string): Promise<User> {
    const user = this.userRepository.create({ name, email });
    return this.userRepository.save(user);
  }

  async findAll(page: number = 1, limit: number = 10): Promise<{ data: User[]; total: number; page: number; limit: number }> {
    const [data, total] = await this.userRepository.findAndCount({
      skip: (page - 1) * limit,
      take: limit,
      order: {
        id: 'ASC',
      },
    });
    return { data, total, page, limit };
  }

  async getDbInfo() {
    // Explicitly create query runner on slave to run raw verification query
    const slaveQueryRunner = this.userRepository.manager.connection.createQueryRunner('slave');
    let replicaInfo;
    try {
      replicaInfo = await slaveQueryRunner.query(
        "SELECT pg_is_in_recovery() AS is_replica, current_setting('port') as port, inet_server_addr() as server_ip"
      );
    } finally {
      await slaveQueryRunner.release();
    }

    // Explicitly create query runner on master to run raw verification query
    const masterQueryRunner = this.userRepository.manager.connection.createQueryRunner('master');
    let masterInfo;
    try {
      masterInfo = await masterQueryRunner.query(
        "SELECT pg_is_in_recovery() AS is_replica, current_setting('port') as port, inet_server_addr() as server_ip"
      );
    } finally {
      await masterQueryRunner.release();
    }

    return {
      readConnection: {
        description: 'Routed automatically to Slave (read-only replica)',
        is_replica: replicaInfo[0].is_replica,
        port: replicaInfo[0].port,
        server_ip: replicaInfo[0].server_ip,
      },
      writeConnection: {
        description: 'Routed automatically to Master (read-write primary)',
        is_replica: masterInfo[0].is_replica,
        port: masterInfo[0].port,
        server_ip: masterInfo[0].server_ip,
      },
    };
  }
}
