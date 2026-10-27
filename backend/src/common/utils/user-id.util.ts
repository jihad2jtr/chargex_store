// البادئة المستخدمة في آيدي المستخدمين المتولدة — أحرف كبيرة (JGO26102712345)
export const USER_ID_PREFIX = 'JGO';

const escapeRegExp = (value: string): string =>
  value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// آيدي قديمة مخزّنة بأحرف صغيرة (jgo.../chx...) وأخرى متولدة بأحرف كبيرة (JGO...)،
// لذلك أي بحث بالآيدي يجب ألا يفرّق بين الحروف وإلا فشل وصول المستخدم لبياناته.
// يُرجى استخدام هذا الفلتر مكان { userId: cleanId } في كل عمليات البحث بالآيدي.
export function userIdFilter(raw: string): Record<string, any> {
  const clean = (raw ?? '').toString().trim();
  // فراغ = لا يطابق أي حساب بدل أن يطابق من لا يملك آيدي
  if (!clean) return { userId: { $in: [] as string[] } };
  return { userId: new RegExp(`^${escapeRegExp(clean)}$`, 'i') };
}

// الصيغة: البادئة + yyMMdd + 5 أرقام عشوائية (11 رقماً بعد البادئة)
export function buildUserIdCandidate(now: Date = new Date()): string {
  const yy = String(now.getFullYear()).slice(-2);
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const rand = Math.floor(10000 + Math.random() * 90000);
  return `${USER_ID_PREFIX}${yy}${mm}${dd}${rand}`;
}

// يولّد آيدي غير مستخدم: يقبل دالة تفحص الترشيح، ويُفضَّل أن تكون لا تفرّق بين
// الحروف كي لا يُولَّد JGO... بينما يوجد jgo... لنفس الأرقام
export async function generateUserId(
  isTaken: (candidateId: string) => Promise<unknown>,
): Promise<string> {
  let candidateId = buildUserIdCandidate();
  while (await isTaken(candidateId)) {
    candidateId = buildUserIdCandidate();
  }
  return candidateId;
}
