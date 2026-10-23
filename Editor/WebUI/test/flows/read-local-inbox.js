var result = http.get('http://127.0.0.1:28088/');
var escaped = EMAIL.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
var match = new RegExp(escaped + ': <strong>([0-9]{6})</strong>').exec(result.body);
if (!match) throw new Error('Test OTP not delivered to the local mailbox');
output.otp = match[1];
