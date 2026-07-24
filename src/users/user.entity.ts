import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';
import { ApiProperty } from '@nestjs/swagger';

@Entity()
export class User {
  @PrimaryGeneratedColumn()
  @ApiProperty({ example: 1, description: 'The unique auto-incremented identifier of the user' })
  id: number;

  @Column()
  @ApiProperty({ example: 'Alice Smith', description: 'The full name of the user' })
  name: string;

  @Column()
  @ApiProperty({ example: 'alice@example.com', description: 'The email address of the user' })
  email: string;
}
