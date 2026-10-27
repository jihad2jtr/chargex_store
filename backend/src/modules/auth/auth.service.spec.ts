import { Types } from 'mongoose';
import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service.js';

// مستند وهمي قابل للتعديل والحفظ، يحاكي وثيقة mongoose
const makeUser = (overrides: any = {}) => {
  const doc: any = {
    _id: new Types.ObjectId(),
    name: 'عميل تجريبي',
    email: 'client@example.com',
    phone: '0900123456',
    avatar: undefined,
    password: 'hashed-secret',
    refreshToken: 'refresh-token',
    save: async () => doc,
    toObject: () => ({ ...doc }),
    ...overrides,
  };
  return doc;
};

const makeService = (user: any) => {
  const userModel = { findById: async () => user } as any;
  return new AuthService(userModel, {} as any, {} as any);
};

describe('AuthService.updateProfile', () => {
  const id = new Types.ObjectId().toString();

  it('saves a valid avatar url and never leaks credentials', async () => {
    const service = makeService(makeUser());

    const result = await service.updateProfile(id, {
      avatar: 'http://192.168.1.198:3000/uploads/img_1.jpg',
    });

    expect(result.avatar).toBe('http://192.168.1.198:3000/uploads/img_1.jpg');
    expect(result.password).toBeUndefined();
    expect(result.refreshToken).toBeUndefined();
  });

  it('accepts a local /uploads path and clears the avatar when emptied', async () => {
    const user = makeUser({ avatar: '/uploads/img_old.jpg' });
    const service = makeService(user);

    expect(
      (await service.updateProfile(id, { avatar: '/uploads/a.png' })).avatar,
    ).toBe('/uploads/a.png');
    expect(
      (await service.updateProfile(id, { avatar: '   ' })).avatar,
    ).toBeUndefined();
  });

  it('rejects an avatar that is not an image url', async () => {
    const service = makeService(makeUser());

    await expect(
      service.updateProfile(id, { avatar: 'data:,not-a-url' }),
    ).rejects.toThrow(BadRequestException);
  });

  it('validates name and phone before saving', async () => {
    const service = makeService(makeUser());

    await expect(service.updateProfile(id, { name: 'أ' })).rejects.toThrow(
      BadRequestException,
    );
    await expect(service.updateProfile(id, { phone: 'abc' })).rejects.toThrow(
      BadRequestException,
    );
  });

  it('keeps untouched fields when only the avatar changes', async () => {
    const user = makeUser();
    const service = makeService(user);

    const result = await service.updateProfile(id, {
      avatar: '/uploads/new.png',
    });

    expect(result.name).toBe('عميل تجريبي');
    expect(result.phone).toBe('0900123456');
  });

  it('throws when the account no longer exists', async () => {
    const service = makeService(null);

    await expect(
      service.updateProfile(id, { avatar: '/uploads/a.png' }),
    ).rejects.toThrow(UnauthorizedException);
  });
});
