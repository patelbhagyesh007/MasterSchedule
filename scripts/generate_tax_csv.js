const fs = require('fs');
const path = require('path');

const dataPath = path.join(__dirname, '..', 'schedule_data.json');
if (!fs.existsSync(dataPath)) {
  console.error('schedule_data.json not found at', dataPath);
  process.exit(1);
}

const raw = fs.readFileSync(dataPath, 'utf8');
const data = JSON.parse(raw);

const settings = data.settings || {};
const employerPct = Number(settings.tax || settings.employerCostPercent || 0);

const staff = data.staff || [];

const rows = [];
let totalWeekly = 0;
let totalAnnual = 0;
let totalEmployerAnnual = 0;

staff.forEach(p => {
  const weekly = p.weeklyPay || (p.rate && p.type !== 'salary' ? (p.rate * (p.weeklyHours || 0)) : 0);
  // if no weeklyPay, best-effort: assume rate is hourly and use hours from shifts if present
  const annual = p.annualPay || (weekly * 52);
  const employerAnnual = annual * (employerPct / 100);
  totalWeekly += weekly;
  totalAnnual += annual;
  totalEmployerAnnual += employerAnnual;
  rows.push({ name: p.name, weekly, annual, employerWeekly: employerAnnual / 52, employerAnnual });
});

const headers = ['Employee','Weekly Pay','Annual Pay','Employer Tax (weekly)','Employer Tax (annual)'];
const lines = [headers.join(',')];
rows.forEach(r => {
  lines.push([r.name, r.weekly.toFixed(2), r.annual.toFixed(2), r.employerWeekly.toFixed(2), r.employerAnnual.toFixed(2)].map(x => `"${x}"`).join(','));
});
lines.push(['Totals', totalWeekly.toFixed(2), totalAnnual.toFixed(2), (totalEmployerAnnual/52).toFixed(2), totalEmployerAnnual.toFixed(2)].map(x => `"${x}"`).join(','));

const out = lines.join('\n');
const outPath = path.join(__dirname, '..', 'employer_tax_breakdown.csv');
fs.writeFileSync(outPath, out, 'utf8');
console.log('Wrote', outPath);
console.log('---');
console.log(out);
