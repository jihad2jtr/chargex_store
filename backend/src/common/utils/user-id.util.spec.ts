import {
  USER_ID_PREFIX,
  buildUserIdCandidate,
  generateUserId,
  userIdFilter,
} from './user-id.util.js';

describe('user id generation', () => {
  it('generates ids with an uppercase JGO prefix followed by 11 digits', () => {
    expect(USER_ID_PREFIX).toBe('JGO');

    const candidate = buildUserIdCandidate(new Date(2026, 9, 27));

    expect(candidate).toMatch(/^JGO\d{11}$/);
    expect(candidate.startsWith('JGO261027')).toBe(true);
  });

  it('returns the first candidate that is not already taken', async () => {
    const tried: string[] = [];
    const result = await generateUserId(async (candidateId) => {
      tried.push(candidateId);
      return tried.length === 1; // أول ترشيح مستخدم بالفعل
    });

    expect(tried).toHaveLength(2);
    expect(result).toBe(tried[1]);
    expect(result).toMatch(/^JGO\d{11}$/);
  });
});

describe('userIdFilter', () => {
  const filterOf = (raw: string) => userIdFilter(raw).userId as RegExp;

  it('matches the stored id whatever the typed casing is', () => {
    // آيدي قديمة صغيرة وأخرى متولدة كبيرة، والمدخل قد يكون بأي حالة
    expect(filterOf('JGO26102712345').test('jgo26102712345')).toBe(true);
    expect(filterOf('jgo26102712345').test('JGO26102712345')).toBe(true);
    expect(filterOf('Chx26101512345').test('chx26101512345')).toBe(true);
  });

  it('matches the whole id only, and tolerates spaces around it', () => {
    expect(filterOf('  JGO26102712345  ').test('JGO261027123456')).toBe(false);
    expect(filterOf('JGO26102712345').test('JGO26102754321')).toBe(false);
  });

  it('treats regex metacharacters in the input as literal text', () => {
    expect(filterOf('JGO.26102712345').test('JGOX26102712345')).toBe(false);
    expect(filterOf('JGO.26102712345').test('JGO.26102712345')).toBe(true);
  });

  it('matches nothing when the id is empty', () => {
    // فراغ لا يجب أن يطابق الحسابات التي لا تملك آيدي
    expect(userIdFilter('')).toEqual({ userId: { $in: [] } });
    expect(userIdFilter('   ')).toEqual({ userId: { $in: [] } });
  });
});
