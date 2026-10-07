"use client";
import type { Hex } from "viem";

// Talks to the patient's Ledger from the browser through Ledger's Device Management Kit.
//   speculos  (default): Ledger's emulator, started with `npm run speculos`
//   webhid:   a real Ledger over USB (Chrome/Edge)
//   simulated: no device at all; the server signs with a dev key
export const transport = (process.env.NEXT_PUBLIC_LEDGER_TRANSPORT ?? "speculos") as "speculos" | "webhid" | "simulated";
export const SPECULOS_URL = process.env.NEXT_PUBLIC_SPECULOS_URL ?? "http://localhost:5005";
const PATH = "44'/60'/0'/0/0";

type Signer = import("@ledgerhq/device-signer-kit-ethereum").SignerEth;
let signerPromise: Promise<Signer> | null = null;

async function connect(): Promise<Signer> {
  const { DeviceManagementKitBuilder } = await import("@ledgerhq/device-management-kit");
  const { SignerEthBuilder } = await import("@ledgerhq/device-signer-kit-ethereum");
  const { firstValueFrom } = await import("rxjs");
  const factory =
    transport === "webhid"
      ? (await import("@ledgerhq/device-transport-kit-web-hid")).webHidTransportFactory
      : (await import("@ledgerhq/device-transport-kit-speculos")).speculosTransportFactory(SPECULOS_URL);
  const dmk = new DeviceManagementKitBuilder().addTransport(factory).build();
  const device = await firstValueFrom(dmk.startDiscovering({}));
  const sessionId = await dmk.connect({ device });
  return new SignerEthBuilder({ dmk, sessionId }).build();
}

function getSigner() {
  signerPromise ??= connect().catch((e) => {
    signerPromise = null; // allow retry
    throw e;
  });
  return signerPromise;
}

// Resolve a DMK device action observable into its output.
async function run<T>(action: { observable: import("rxjs").Observable<unknown> }): Promise<T> {
  const { DeviceActionStatus } = await import("@ledgerhq/device-management-kit");
  return new Promise((resolve, reject) => {
    action.observable.subscribe({
      next: (s) => {
        const state = s as { status: string; output?: T; error?: { message?: string; _tag?: string } };
        if (state.status === DeviceActionStatus.Completed) resolve(state.output as T);
        if (state.status === DeviceActionStatus.Error)
          reject(new Error(state.error?.message ?? state.error?._tag ?? "Ledger error"));
      },
      error: reject,
    });
  });
}

export async function getLedgerAddress(): Promise<Hex> {
  const signer = await getSigner();
  const { address } = await run<{ address: Hex }>(signer.getAddress(PATH));
  return address;
}

// Shows the consent text on the Ledger; resolves once the patient holds to sign.
export async function signOnLedger(message: string): Promise<Hex> {
  const signer = await getSigner();
  const { r, s, v } = await run<{ r: Hex; s: Hex; v: number }>(signer.signMessage(PATH, message));
  const pad = (h: Hex) => h.slice(2).padStart(64, "0");
  return `0x${pad(r)}${pad(s)}${v.toString(16).padStart(2, "0")}`;
}
