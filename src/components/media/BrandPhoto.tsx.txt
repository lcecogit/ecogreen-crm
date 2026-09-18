import Image from "next/image";

interface BrandPhotoProps {
  src: string;
  alt: string;
  className?: string;
}

export function BrandPhoto({ src, alt, className = "" }: BrandPhotoProps) {
  return (
    <div className={`overflow-hidden rounded-2xl border border-[var(--hairline)] bg-[var(--surface-sunken)] ${className}`}>
      <Image
        src={src}
        alt={alt}
        width={800}
        height={600}
        className="w-full h-full object-cover transition-transform duration-500 hover:scale-105"
      />
    </div>
  );
}