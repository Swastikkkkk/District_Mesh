import { useRef } from "react"
import gsap from "gsap"
import { useGSAP } from "@gsap/react"
import { LuSmartphone } from "react-icons/lu"
import { Section } from "@/components/Section"

const nodes = [
  { name: "Arjun", x: 8, ttl: "sends" },
  { name: "Aman", x: 36, ttl: "ttl 9" },
  { name: "Kabir", x: 64, ttl: "ttl 8" },
  { name: "Zoya", x: 92, ttl: "ttl 7" },
]

export function HowItWorks() {
  const root = useRef<HTMLDivElement>(null)
  useGSAP(() => {
    const tl = gsap.timeline({ repeat: -1, repeatDelay: 1, scrollTrigger: { trigger: root.current, start: "top 75%" } })
    tl.set(".packet", { left: "8%", opacity: 0 })
      .set(".node-dot", { backgroundColor: "rgba(255,255,255,0.06)", borderColor: "rgba(255,255,255,0.12)" })
      .set(".node-label", { opacity: 0.35 })
      .to(".node-0 .node-dot", { backgroundColor: "#855aff", borderColor: "#855aff", duration: 0.3 })
      .to(".node-0 .node-label", { opacity: 1, duration: 0.3 }, "<")
      .to(".packet", { opacity: 1, duration: 0.2 })
    ;[1, 2, 3].forEach(i => {
      tl.to(".packet", { left: `${nodes[i].x}%`, duration: 1, ease: "power2.inOut" })
        .to(`.node-${i} .node-dot`, { backgroundColor: "#855aff", borderColor: "#855aff", duration: 0.25 })
        .to(`.node-${i} .node-label`, { opacity: 1, duration: 0.25 }, "<")
    })
    tl.to(".packet", { opacity: 0, duration: 0.3 }).to({}, { duration: 1.2 })
  }, { scope: root })

  return (
    <Section id="how" eyebrow="How it works" title="Every phone is a relay."
      intro="Phones within range link up directly. When a message arrives, each phone passes it on to its other neighbours, so it reaches people far outside your own range. Each phone forwards a message once, and a hop limit stops it from bouncing around forever.">
      <div ref={root} className="reveal rounded-3xl border border-line bg-surface/60 p-6 sm:p-10">
        <div className="relative h-36 sm:h-40">
          <div className="absolute left-[8%] right-[8%] top-[28px] h-px sm:top-[34px] bg-gradient-to-r from-white/5 via-white/15 to-white/5" />
          <div className="packet absolute top-[22px] h-3 w-3 sm:top-[28px] -translate-x-1/2 rounded-full bg-white shadow-[0_0_14px_3px_rgba(180,156,255,0.7)]" />
          {nodes.map((n, i) => (
            <div key={n.name} className={`node-${i} absolute top-0 flex -translate-x-1/2 flex-col items-center`} style={{ left: `${n.x}%` }}>
              <div className="node-dot flex h-14 w-14 items-center sm:h-[68px] sm:w-[68px] justify-center rounded-2xl border border-white/12 bg-white/5">
                <LuSmartphone className="h-6 w-6 text-white sm:h-7 sm:w-7" />
              </div>
              <div className="node-label mt-3 text-center">
                <div className="text-[14px] font-medium">{n.name}</div>
                <div className="font-mono text-[11px] text-white/45">{n.ttl}</div>
              </div>
            </div>
          ))}
        </div>
        <div className="mt-8 grid gap-4 border-t border-line pt-8 text-[15px] text-white/55 sm:grid-cols-3">
          <p><span className="font-medium text-white">Arjun and Zoya are never in range of each other.</span> The message still reaches Zoya through Aman and Kabir.</p>
          <p><span className="font-medium text-white">Each phone delivers a message once.</span> Repeat copies that loop back are ignored.</p>
          <p><span className="font-medium text-white">Up to 10 hops.</span> A hop counter on every message keeps the network quiet.</p>
        </div>
      </div>
    </Section>
  )
}
