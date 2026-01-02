import http from 'k6/http';
import { sleep, check } from 'k6';

export let options = {
    vus: 1000,
    duration: '5m',
};

export default function() {
    let res = http.get('http://127.0.0.1:10000/hello');
    check(res, { 'Query successfully': (resp) => resp.body == 'hello world!' });
    sleep(10);
}
