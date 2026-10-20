import { trvQuery } from './lib.mjs';
const [objecttype, schema, filter = '', extra = ''] = process.argv.slice(2);
const r = await trvQuery(`<QUERY objecttype="${objecttype}" schemaversion="${schema}" ${extra}><FILTER>${filter}</FILTER></QUERY>`);
console.log(JSON.stringify(r, null, 1).slice(0, 4000));
