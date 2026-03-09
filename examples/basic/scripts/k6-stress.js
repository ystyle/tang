// scripts/k6-stress.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    find_capacity: {
      executor: 'ramping-vus',

      // 起始100个VU，逐步增加
      startVUs: 100,

      stages: [
        // { 持续时间, 目标VU数 }
        { duration: '30s', target: 500 },    // 30秒热身到500并发
        { duration: '1m', target: 1000 },    // 1分钟到1000并发
        { duration: '1m', target: 2000 },    // 1分钟到2000并发
        { duration: '1m', target: 4000 },    // 1分钟到4000并发
        { duration: '1m', target: 6000 },    // 1分钟到6000并发
        { duration: '1m', target: 8000 },    // 1分钟到8000并发
        { duration: '2m', target: 8000 },    // 保持2分钟观察稳定性
        { duration: '30s', target: 0 },      // 30秒降载
      ],

      gracefulRampDown: '30s',  // 平滑下降
    },
  },

  thresholds: {
    http_req_failed: [{ threshold: 'rate<0.05', abortOnFail: true }],
    http_req_duration: [{ threshold: 'p(95)<500', abortOnFail: false }],
  },
};

export default function () {
  const res = http.get('http://localhost:10000/hello');
  check(res, { 'status was 200': (r) => r.status === 200 });
}
