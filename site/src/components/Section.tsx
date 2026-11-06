import type { ReactNode } from "react"
import { cn } from "@/lib/utils"

export function Section({ id, eyebrow, title, intro, children, className }: {
  id?: string; eyebrow: string; title: string; intro?: string; children: ReactNode; className?: string
}) {
  return (
    <section id={id} className={cn("relative mx-auto max-w-6xl scroll-mt-24 px-5 py-16 sm:px-8 sm:py-20", className)}>
      <div className="section-heading max-w-2xl">
        <p className="text-[13px] font-semibold uppercase tracking-[0.18em] text-accent-soft">{eyebrow}</p>
        <h2 className="mt-3 text-[38px] leading-[0.98] tracking-[-0.015em] text-white sm:text-[52px] sm:leading-[1.02]">{title}</h2>
        {intro && <p className="mt-4 text-[17px] leading-relaxed text-white/55">{intro}</p>}
      </div>
      <div className="section-content mt-10">{children}</div>
    </section>
  )
}
