"use client";
import type { Hex } from "viem";

// The school's Ledger, through Ledger's Device Management Kit (the successor to
// the hw-transport-webusb libraries): send text to the device, the person
// reviews it and signs on the device.
//   speculos (default): a second emulator for the school, scripts/speculos-school.sh
//   webhid: a real Ledger over USB (Chrome/Edge)
const transport = process.env.NEXT_PUBLIC_LEDGER_TRANSPORT === "webhid" ? "webhid" : "speculos";
export const SPECULOS_URL = process.env.NEXT_PUBLIC_SPECULOS_URL ?? "http://localhost:5006";
export const usingEmulator = transport === "speculos";
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
    signerPromise = null;
    throw e;
  });
  return signerPromise;
}

async function run<T>(action: { observable: import("rxjs").Observable<unknown> }): Promise<T> {
  const { DeviceActionStatus } = await import("@ledgerhq/device-management-kit");
  return new Promise((resolve, reject) => {
    action.observable.subscribe({
      next: (s) => {
        const state = s as { status: string; output?: T; error?: { message?: string; _tag?: string } };
        if (state.status === DeviceActionStatus.Completed) resolve(state.output as T);
        if (state.status === DeviceActionStatus.Error) reject(new Error(state.error?.message ?? state.error?._tag ?? "Ledger error"));
      },
      error: reject,
    });
  });
}

export async function getLedgerAddress(): Promise<Hex> {
  const { address } = await run<{ address: Hex }>((await getSigner()).getAddress(PATH));
  return address.toLowerCase() as Hex;
}

/** Shows `message` on the Ledger; resolves once the person holds to sign. */
export async function signOnLedger(message: string): Promise<Hex> {
  const { r, s, v } = await run<{ r: Hex; s: Hex; v: number }>((await getSigner()).signMessage(PATH, message));
  const pad = (h: Hex) => h.slice(2).padStart(64, "0");
  return `0x${pad(r)}${pad(s)}${v.toString(16).padStart(2, "0")}`;
}
