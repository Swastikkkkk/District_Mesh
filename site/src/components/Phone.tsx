import { cn } from "@/lib/utils"

export function Phone({ src, alt, className }: { src: string; alt: string; className?: string }) {
  return (
    <div className={cn("relative aspect-[9/19.5] rounded-[2.6rem] bg-[#1b1a22] p-[7px] shadow-[0_30px_80px_-20px_rgba(0,0,0,0.9)] ring-1 ring-white/10", className)}>
      <div className="relative h-full w-full overflow-hidden rounded-[2.15rem] bg-black">
        <img src={src} alt={alt} loading="lazy" className="h-full w-full object-cover object-top" />
      </div>
    </div>
  )
}
