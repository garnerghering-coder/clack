// Small shared caches for reference data.
import { useEffect, useState } from 'react';
import { api, type Operator } from './api';

let operatorsPromise: Promise<Map<string, Operator>> | null = null;
export function useOperators(): Map<string, Operator> {
  const [ops, setOps] = useState<Map<string, Operator>>(new Map());
  useEffect(() => {
    operatorsPromise ??= api.operators().then((list) => new Map(list.map((o) => [o.id, o])));
    operatorsPromise.then(setOps, () => {
      operatorsPromise = null;
    });
  }, []);
  return ops;
}
