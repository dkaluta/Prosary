import type { EditorAudioTrack, EditorImage, Project } from "../format/project";
import {
  newProject,
  pruneUnusedImages,
} from "../format/project";

/** Kept only to migrate autosaves written before binary media moved to IndexedDB. */
export const LEGACY_AUTOSAVE_KEY = "prosary-compose-autosave";

const DATABASE_NAME = "prosary-compose";
const DATABASE_VERSION = 1;
const PROJECT_STORE = "projects";
const ASSET_STORE = "assets";
const CURRENT_PROJECT_KEY = "current";

type ImageMetadata = Omit<EditorImage, "jpeg">;
type AudioMetadata = Omit<EditorAudioTrack, "bytes">;
type ProjectMetadata = Omit<Project, "images" | "audio"> & {
  images: ImageMetadata[];
  audio: AudioMetadata[];
};

export interface AutosaveRecord {
  prosaryComposeAutosave: 1;
  project: ProjectMetadata;
}

export interface AutosaveParts {
  record: AutosaveRecord;
  assets: Map<string, Uint8Array>;
}

const imageAssetKey = (uid: string) => `image:${uid}`;
const audioAssetKey = (uid: string) => `audio:${uid}`;

/** Split frequently-changing editor metadata from immutable binary uploads. IndexedDB can then
 * update a small record after typing without cloning every JPEG and recording again. */
export function splitAutosaveProject(project: Project): AutosaveParts {
  const normalized = pruneUnusedImages(project);
  const assets = new Map<string, Uint8Array>();
  return {
    record: {
      prosaryComposeAutosave: 1,
      project: {
        ...normalized,
        images: normalized.images.map(({ jpeg, ...metadata }) => {
          assets.set(imageAssetKey(metadata.uid), jpeg);
          return metadata;
        }),
        audio: normalized.audio.map(({ bytes, ...metadata }) => {
          assets.set(audioAssetKey(metadata.uid), bytes);
          return metadata;
        }),
      },
    },
    assets,
  };
}

/** Pure inverse used by both IndexedDB restoration and the dependency-free e2e regression. */
export function joinAutosaveProject(
  record: AutosaveRecord,
  assets: ReadonlyMap<string, Uint8Array>,
): Project {
  if (record?.prosaryComposeAutosave !== 1 || !record.project) {
    throw new Error("The local autosave has an unsupported format.");
  }
  const raw = record.project;
  const requiredAsset = (key: string): Uint8Array => {
    const bytes = assets.get(key);
    if (!bytes) throw new Error("The local autosave is missing one of its media files.");
    return bytes;
  };
  return pruneUnusedImages({
    ...newProject(),
    ...raw,
    images: (raw.images ?? []).map((image) => ({
      ...image,
      jpeg: requiredAsset(imageAssetKey(image.uid)),
    })),
    audio: (raw.audio ?? []).map((track) => ({
      ...track,
      bytes: requiredAsset(audioAssetKey(track.uid)),
    })),
  });
}

let databasePromise: Promise<IDBDatabase> | undefined;
let persistedAssets = new Map<string, Uint8Array>();
let operationQueue: Promise<void> = Promise.resolve();

/** Binary values are immutable in editor state. A same-uid replacement gets a new Uint8Array,
 * so identity detects it without re-hashing every large upload after each keystroke. */
export function changedAutosaveAssetKeys(
  current: ReadonlyMap<string, Uint8Array>,
  previous: ReadonlyMap<string, Uint8Array>,
): string[] {
  const changed: string[] = [];
  for (const [key, bytes] of current) {
    if (previous.get(key) !== bytes) changed.push(key);
  }
  return changed;
}

function openDatabase(): Promise<IDBDatabase> {
  if (!globalThis.indexedDB) {
    return Promise.reject(new Error("This browser does not provide IndexedDB."));
  }
  if (databasePromise) return databasePromise;
  const opening = new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(DATABASE_NAME, DATABASE_VERSION);
    let abandoned = false;
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(PROJECT_STORE)) {
        database.createObjectStore(PROJECT_STORE);
      }
      if (!database.objectStoreNames.contains(ASSET_STORE)) {
        database.createObjectStore(ASSET_STORE);
      }
    };
    request.onsuccess = () => {
      const database = request.result;
      if (abandoned) {
        database.close();
        return;
      }
      database.onversionchange = () => {
        database.close();
        if (databasePromise === opening) databasePromise = undefined;
      };
      resolve(database);
    };
    request.onerror = () => {
      abandoned = true;
      reject(request.error ?? new Error("Could not open local storage."));
    };
    request.onblocked = () => {
      abandoned = true;
      reject(new Error("Local storage is open in another tab."));
    };
  });
  databasePromise = opening;
  void opening.catch(() => {
    if (databasePromise === opening) databasePromise = undefined;
  });
  return opening;
}

function requestValue<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("Local storage request failed."));
  });
}

function transactionDone(transaction: IDBTransaction): Promise<void> {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onabort = () => reject(transaction.error ?? new Error("Local storage was interrupted."));
    transaction.onerror = () => reject(transaction.error ?? new Error("Local storage failed."));
  });
}

function enqueue<T>(operation: () => Promise<T>): Promise<T> {
  const result = operationQueue.then(operation, operation);
  operationQueue = result.then(
    () => undefined,
    () => undefined,
  );
  return result;
}

async function readIndexedAutosave(): Promise<Project | null> {
  const database = await openDatabase();
  const transaction = database.transaction([PROJECT_STORE, ASSET_STORE], "readonly");
  const done = transactionDone(transaction);
  const recordRequest = transaction.objectStore(PROJECT_STORE).get(CURRENT_PROJECT_KEY);
  const keysRequest = transaction.objectStore(ASSET_STORE).getAllKeys();
  const assetsRequest = transaction.objectStore(ASSET_STORE).getAll();
  const [record, keys, values] = await Promise.all([
    requestValue(recordRequest),
    requestValue(keysRequest),
    requestValue(assetsRequest),
    done,
  ]);
  const assets = new Map<string, Uint8Array>();
  keys.forEach((key, index) => {
    if (typeof key !== "string") return;
    const value = values[index];
    if (value instanceof Uint8Array) assets.set(key, value);
    else if (value instanceof ArrayBuffer) assets.set(key, new Uint8Array(value));
  });
  persistedAssets = assets;
  if (!record) return null;
  return joinAutosaveProject(record as AutosaveRecord, assets);
}

async function readLegacyAutosave(): Promise<Project | null> {
  try {
    const saved = localStorage.getItem(LEGACY_AUTOSAVE_KEY);
    if (!saved) return null;
    const { deserializeProject } = await import("../format/projectFile");
    return deserializeProject(saved);
  } catch {
    return null;
  }
}

function forgetLegacyAutosave(): void {
  try {
    localStorage.removeItem(LEGACY_AUTOSAVE_KEY);
  } catch {
    // Private browsing policies may disable localStorage independently of IndexedDB.
  }
}

/** Restore native binary state first, then migrate the former base64 localStorage record once. */
export async function loadAutosave(): Promise<Project | null> {
  try {
    const stored = await readIndexedAutosave();
    if (stored) return stored;
  } catch {
    // A usable legacy autosave is still better than a blank project when IndexedDB is blocked.
  }
  const legacy = await readLegacyAutosave();
  if (!legacy) return null;
  try {
    await saveAutosave(legacy);
  } catch {
    // Keep the legacy copy until a native save succeeds.
  }
  return legacy;
}

/** Persist metadata every time, but write each immutable upload only once under its uid. */
export function saveAutosave(project: Project): Promise<void> {
  const { record, assets } = splitAutosaveProject(project);
  return enqueue(async () => {
    const database = await openDatabase();
    const transaction = database.transaction([PROJECT_STORE, ASSET_STORE], "readwrite");
    const done = transactionDone(transaction);
    transaction.objectStore(PROJECT_STORE).put(record, CURRENT_PROJECT_KEY);
    const assetStore = transaction.objectStore(ASSET_STORE);
    for (const key of changedAutosaveAssetKeys(assets, persistedAssets)) {
      assetStore.put(assets.get(key)!, key);
    }
    for (const key of persistedAssets.keys()) {
      if (!assets.has(key)) assetStore.delete(key);
    }
    await done;
    persistedAssets = new Map(assets);
    forgetLegacyAutosave();
  });
}

export function clearAutosave(): Promise<void> {
  forgetLegacyAutosave();
  return enqueue(async () => {
    const database = await openDatabase();
    const transaction = database.transaction([PROJECT_STORE, ASSET_STORE], "readwrite");
    const done = transactionDone(transaction);
    transaction.objectStore(PROJECT_STORE).delete(CURRENT_PROJECT_KEY);
    transaction.objectStore(ASSET_STORE).clear();
    await done;
    persistedAssets.clear();
  });
}
