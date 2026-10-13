import { SAMPLE_EXPORT } from "@/lib/epic-export";

// Simulated Epic MyChart export (the import is faked for the demo).
export function GET() {
  return Response.json(SAMPLE_EXPORT);
}
