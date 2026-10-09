import fs from "node:fs";

const base =
  process.env.CAMPULSE_ACCEPTANCE_BASE_URL || "https://campus.allezafrique.cn";
const users = JSON.parse(
  fs.readFileSync(
    process.env.CAMPULSE_TEST_USERS || ".tools/remote-test-users.json",
    "utf8",
  ),
).slice(0, 2);
if (users.length !== 2) throw new Error("需要两名普通测试用户");

async function request(path, method = "GET", token, body) {
  const response = await fetch(base + path, {
    method,
    headers: {
      ...(token
        ? { Authorization: path.startsWith("/ai/") ? `Bearer ${token}` : token }
        : {}),
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(15000),
  });
  const data = await response.json().catch(() => ({}));
  return { status: response.status, data };
}

function expect(label, actual, expected) {
  if (actual !== expected)
    throw new Error(`${label}: HTTP ${actual}，预期 ${expected}`);
  console.log(`PASS ${label}: HTTP ${actual}`);
}

const [a, b] = await Promise.all(
  users.map(async (user) => {
    const response = await request(
      "/api/collections/users/auth-with-password",
      "POST",
      null,
      {
        identity: user.email,
        password: user.password,
      },
    );
    expect("普通用户登录", response.status, 200);
    if (!response.data.record?.verified) throw new Error("测试账号尚未验证");
    return { id: response.data.record.id, token: response.data.token };
  }),
);

if (process.env.CAMPULSE_TEST_PDF) {
  const pdf = fs.readFileSync(process.env.CAMPULSE_TEST_PDF);
  const form = new FormData();
  for (const [key, value] of Object.entries({
    owner: a.id,
    courseId: "acceptance-course",
    title: `PDF 验收 ${Date.now()}`,
    content: "PDF text extraction sample 2026-10-09",
    schemaVersion: "1",
  }))
    form.set(key, value);
  form.set(
    "attachment",
    new Blob([pdf], { type: "application/pdf" }),
    "notebook-acceptance.pdf",
  );
  const uploadResponse = await fetch(
    `${base}/api/collections/course_notes/records`,
    {
      method: "POST",
      headers: { Authorization: a.token },
      body: form,
      signal: AbortSignal.timeout(15000),
    },
  );
  expect("上传受保护 PDF", uploadResponse.status, 200);
  const uploaded = await uploadResponse.json();
  const notePath = `/api/collections/course_notes/records/${uploaded.id}`;
  try {
    if (!uploaded.attachment) throw new Error("PDF 文件字段未返回");
    const foreign = await request(notePath, "GET", b.token);
    if (![403, 404].includes(foreign.status))
      throw new Error(`跨用户读取 PDF 笔记未被阻止：HTTP ${foreign.status}`);
    console.log(`PASS 跨用户 PDF 笔记隔离: HTTP ${foreign.status}`);
    const fileToken = await request("/api/files/token", "POST", a.token);
    expect("获取受保护文件临时令牌", fileToken.status, 200);
    const fileUrl = `${base}/api/files/course_notes/${uploaded.id}/${encodeURIComponent(uploaded.attachment)}?token=${encodeURIComponent(fileToken.data.token)}`;
    const downloaded = await fetch(fileUrl, {
      signal: AbortSignal.timeout(15000),
    });
    expect("下载受保护 PDF", downloaded.status, 200);
    if (!Buffer.from(await downloaded.arrayBuffer()).equals(pdf))
      throw new Error("PDF 下载内容与上传内容不一致");
    console.log("PASS PDF 字节完整读回");
  } finally {
    const deleted = await request(notePath, "DELETE", a.token);
    expect("清理专用 PDF 笔记", deleted.status, 204);
  }
}

const card = await request(
  "/api/collections/course_review_cards/records",
  "POST",
  a.token,
  {
    owner: a.id,
    courseId: "acceptance-course",
    front: `验收卡片 ${Date.now()}`,
    back: "仅用于远程复习链路检查",
    due: new Date().toISOString(),
  },
);
expect("创建云端卡片", card.status, 200);
const path = `/api/collections/course_review_cards/records/${card.data.id}`;
try {
  const foreign = await request(path, "GET", b.token);
  if (![403, 404].includes(foreign.status))
    throw new Error(`跨用户读取卡片未被阻止：HTTP ${foreign.status}`);
  console.log(`PASS 跨用户卡片隔离: HTTP ${foreign.status}`);

  const invalid = await request(
    `/ai/v1/cards/${card.data.id}/review`,
    "POST",
    a.token,
    { rating: 5 },
  );
  expect("拒绝无效复习评分", invalid.status, 400);

  const reviewed = await request(
    `/ai/v1/cards/${card.data.id}/review`,
    "POST",
    a.token,
    { rating: 3 },
  );
  expect("FSRS 复习写入", reviewed.status, 200);
  const reloaded = await request(path, "GET", a.token);
  expect("同用户读回卡片", reloaded.status, 200);
  if (
    !reloaded.data.scheduler?.due ||
    !reloaded.data.due ||
    reloaded.data.reviewHistory?.length !== 1
  ) {
    throw new Error("复习后 due、scheduler 或 reviewHistory 未持久化");
  }
  console.log("PASS 复习排程及历史持久化");
} finally {
  const deleted = await request(path, "DELETE", a.token);
  expect("清理专用验收卡片", deleted.status, 204);
}
