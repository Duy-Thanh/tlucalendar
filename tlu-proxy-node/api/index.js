// api/index.js
const https = require('https');
const http = require('http');
const fetch = require('node-fetch');

// 1. CẤU HÌNH AGENT: Tắt Keep-Alive, Bỏ qua SSL
const sslAgent = new https.Agent({
  rejectUnauthorized: false, 
  keepAlive: false, 
});

const httpAgent = new http.Agent({
  keepAlive: false,
});

const UPSTREAM_HOST = 'https://sinhvien1.tlu.edu.vn'; // Dùng HTTPS làm gốc

const AUTH_CONFIG = {
  client_id: 'education_client',
  client_secret: 'password',
  grant_type: 'password',
};

module.exports = async (req, res) => {
  // CORS Setup
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    const { url, method } = req;
    
    // Login Handler
    if (url === '/login' && method === 'POST') {
      return await handleLogin(req, res);
    }

    // Proxy Handler
    return await handleProxy(req, res);

  } catch (error) {
    console.error("Critical Proxy Error:", error);
    // Trả về 502 để App biết đường mà xử lý (nếu cần)
    res.status(502).json({ 
        error: 'Proxy Error', 
        details: error.message,
        code: error.code 
    });
  }
};

// --- CỖ MÁY RETRY BẤT TỬ (QUAN TRỌNG VÃI L**) ---
async function fetchWithRetry(url, options, retries = 5, delay = 1000) {
  try {
    // console.log(`[Attempt] ${url}`);
    const res = await fetch(url, options);
    
    // Nếu server trả về lỗi server (5xx), cũng coi là fail để retry
    if (res.status >= 502) {
        throw new Error(`Server returned ${res.status}`);
    }
    return res;

  } catch (err) {
    const isNetworkError = err.code === 'ECONNRESET' || err.code === 'ETIMEDOUT' || err.code === 'EPROTO';
    const isServerError = err.message.includes('Server returned');

    if (retries > 0 && (isNetworkError || isServerError)) {
      console.log(`[Fail] ${err.code || err.message} -> Retry in ${delay}ms...`);
      
      // Chờ tí
      await new Promise(r => setTimeout(r, delay));
      
      // FALLBACK SANG HTTP (Nếu HTTPS đang lỗi)
      if (url.startsWith('https://') && retries <= 3) {
          const httpUrl = url.replace('https://', 'http://');
          console.log(`[Fallback] Try HTTP: ${httpUrl}`);
          const httpOptions = { ...options, agent: httpAgent }; // Đổi agent sang HTTP
          try {
             return await fetch(httpUrl, httpOptions);
          } catch (e) {
             console.log("[Fallback Fail] HTTP also died");
          }
      }

      // Đệ quy Retry
      return fetchWithRetry(url, options, retries - 1, delay + 1000);
    }
    throw err;
  }
}

async function handleLogin(req, res) {
  const clientBody = req.body || {};
  
  const params = new URLSearchParams();
  params.append('client_id', AUTH_CONFIG.client_id);
  params.append('client_secret', AUTH_CONFIG.client_secret);
  params.append('grant_type', AUTH_CONFIG.grant_type);
  params.append('username', clientBody.studentCode || '');
  params.append('password', clientBody.password || '');

  // Dùng fetchWithRetry
  const response = await fetchWithRetry(`${UPSTREAM_HOST}/education/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params,
    agent: sslAgent
  });

  const data = await response.json();
  res.status(response.status).json(data);
}

async function handleProxy(req, res) {
  let targetPath = req.url;

  const proxyHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36',
    'Referer': `${UPSTREAM_HOST}/`,
    'Accept': 'application/json, text/plain, */*'
  };

  if (req.headers.authorization) {
    proxyHeaders['Authorization'] = req.headers.authorization;
  }

  // Hack Cookie Exam
  if ((targetPath.includes('/registerperiod/find') || targetPath.includes('/semestersubjectexamroom')) && req.headers.authorization) {
     const token = req.headers.authorization.replace('Bearer ', '').trim();
     const cookieVal = encodeURIComponent(JSON.stringify({ access_token: token, token_type: 'bearer' }));
     proxyHeaders['Cookie'] = `token=${cookieVal}`;
  }

  const fetchOptions = {
    method: req.method,
    headers: proxyHeaders,
    agent: sslAgent
  };

  // --- FIX BODY (Cái đoạn mày hỏi đây) ---
  if (req.method !== 'GET' && req.method !== 'HEAD' && req.body) {
    fetchOptions.body = JSON.stringify(req.body);
    proxyHeaders['Content-Type'] = 'application/json';
  }

  // --- GỌI HÀM BẤT TỬ (Đã sửa lại chỗ này) ---
  const response = await fetchWithRetry(`${UPSTREAM_HOST}${targetPath}`, fetchOptions);

  // LỌC RÁC 4MB
  if (targetPath.includes('StudentCourseSubject/studentLoginUser') && response.ok) {
    const originalData = await response.json();
    const cleanData = cleanScheduleResponse(originalData);
    return res.status(200).json(cleanData);
  }

  // Pass-through
  const buffer = await response.buffer();
  res.setHeader('Content-Type', response.headers.get('content-type') || 'application/json');
  res.status(response.status).send(buffer);
}

// Logic dọn rác giữ nguyên (không copy lại cho dài dòng)
function cleanScheduleResponse(data) {
  let list = Array.isArray(data) ? data : [data];
  const cleanedList = list.map(item => {
    const cleanItem = {
      id: item.id,
      status: item.status,
      subjectName: item.subjectName,
      subjectCode: item.subjectCode,
      courseName: item.courseName,
      courseCode: item.courseCode,
      numberOfCredit: item.numberOfCredit,
      credits: item.credits,
      grade: item.grade,
      studentCode: item.studentCode,
      courseSubject: null
    };
    let rawCs = (item.studentCourseSubject && item.studentCourseSubject.courseSubject) || item.courseSubject;
    if (rawCs) {
        cleanItem.courseSubject = {
            id: rawCs.id,
            classCode: rawCs.classCode,
            className: rawCs.className,
            name: rawCs.name,
            lecturer: rawCs.lecturer,
            timetables: rawCs.timetables 
        };
    }
    return cleanItem;
  });
  return Array.isArray(data) ? cleanedList : cleanedList[0];
}