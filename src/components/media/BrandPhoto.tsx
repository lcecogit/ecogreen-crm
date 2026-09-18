import Image from "next/image";

import { cn } from "@/lib/cn";

export type BrandPhotoProps = { src?: string; alt?: string; priority?: boolean; className?: string; sizes?: string };

export function BrandPhoto({ src, alt, priority = false, className, sizes = "(max-width: 768px) 100vw, 50vw" }: BrandPhotoProps) {
  if (!src) return <PhotoFallback className={className} />;
  return (
    <div className={cn("relative overflow-hidden bg-surface-sunken", className)}>
      <Image src={src} alt={alt ?? ""} fill sizes={sizes} priority={priority} quality={82} className="object-cover" />
      <div className="pointer-events-none absolute inset-0 bg-ink-1/[0.04] mix-blend-multiply" aria-hidden />
    </div>
  );
}

export function PhotoFallback({ className }: { className?: string }) {
  return <div className={cn("relative overflow-hidden bg-surface-sunken", className)} aria-hidden><div className="absolute inset-0 opacity-[0.55]" style={{ background: "radial-gradient(120% 90% at 20% 15%, var(--accent-wash) 0%, transparent 60%)" }} /><div className="absolute inset-0" style={{ background: "radial-gradient(100% 100% at 50% 0%, transparent 40%, rgb(0 0 0 / 0.07) 100%)" }} /></div>;
}
