import type { ReactNode } from "react"
import { cn } from "@/lib/utils"

export function Section({ id, eyebrow, title, intro, children, className }: {
  id?: string; eyebrow: string; title: string; intro?: string; children: ReactNode; className?: string
}) {
  return (
    <section id={id} className={cn("relative mx-auto max-w-6xl scroll-mt-24 px-5 py-24 sm:px-8 sm:py-32", className)}>
      <div className="reveal max-w-2xl">
        <p className="text-[13px] font-semibold uppercase tracking-[0.18em] text-accent-soft">{eyebrow}</p>
        <h2 className="mt-3 text-3xl font-semibold tracking-tight text-white sm:text-[44px] sm:leading-[1.08]">{title}</h2>
        {intro && <p className="mt-4 text-[17px] leading-relaxed text-white/55">{intro}</p>}
      </div>
      <div className="mt-14">{children}</div>
    </section>
  )
}
