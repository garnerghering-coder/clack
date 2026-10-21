// Small shared caches for reference data.
import { useEffect, useState } from 'react';
import type { AmenityEntry } from '@clack/shared';
import { api, type Operator, type TrainType } from './api';

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

let typesPromise: Promise<Map<string, TrainType>> | null = null;
export function useTrainTypes(): Map<string, TrainType> {
  const [types, setTypes] = useState<Map<string, TrainType>>(new Map());
  useEffect(() => {
    typesPromise ??= api.trainTypes().then((list) => new Map(list.map((t) => [t.id, t])));
    typesPromise.then(setTypes, () => {
      typesPromise = null;
    });
  }, []);
  return types;
}

let amenitiesPromise: Promise<AmenityEntry[]> | null = null;
/** The typical-amenities table (operator + train type → sourced claims). */
export function useAmenities(): AmenityEntry[] {
  const [table, setTable] = useState<AmenityEntry[]>([]);
  useEffect(() => {
    amenitiesPromise ??= api.amenities();
    amenitiesPromise.then(setTable, () => {
      amenitiesPromise = null;
    });
  }, []);
  return table;
}
