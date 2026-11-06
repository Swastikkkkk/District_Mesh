import { useRef } from "react"
import { Phone } from "@/components/Phone"
import { Section } from "@/components/Section"
import { asset } from "@/lib/site"
import { LuArrowLeft, LuArrowRight } from "react-icons/lu"

const shots = [
  { file: "onboarding", title: "Meet NoBars", body: "No network, no towers, works in Airplane Mode." },
  { file: "walkthrough", title: "Go live", body: "One tap and your phone starts finding your group." },
  { file: "home", title: "Your crew at a glance", body: "Who's nearby, call buttons and chat in one place." },
  { file: "chat", title: "Chat with zero bars", body: "Messages travel phone to phone, no network needed." },
  { file: "sos", title: "SOS alerts", body: "A buddy in trouble gets flagged right on your crew." },
  { file: "map", title: "Find each other", body: "Buddies on the map, SOS in red." },
]

export function Screens() {
  const rail = useRef<HTMLDivElement>(null)

  const scrollScreens = (direction: number) => {
    const firstCard = rail.current?.querySelector<HTMLElement>(".screen-card")
    if (!rail.current || !firstCard) return
    const gap = Number.parseFloat(getComputedStyle(rail.current).columnGap) || 0
    rail.current.scrollBy({ left: direction * (firstCard.offsetWidth + gap), behavior: "smooth" })
  }

  return (
    <Section id="screens" eyebrow="Screens" title="Straight from the app."
      intro="Real screenshots from two simulators meshed together, captured automatically on every build.">
      <div className="relative">
        <div
          ref={rail}
          aria-label="NoBars app screens"
          className="screen-rail -mx-5 flex snap-x snap-mandatory gap-6 overflow-x-auto overscroll-x-contain scroll-px-5 px-5 pb-6 touch-pan-x select-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/70 sm:-mx-8 sm:scroll-px-8 sm:px-8"
          role="region"
          tabIndex={0}
        >
          {shots.map(s => (
            <figure key={s.file} className="screen-card reveal w-[min(72vw,240px)] shrink-0 snap-start">
              <Phone src={asset(`shots/${s.file}.webp`)} alt={s.title} />
              <figcaption className="mt-5 px-1">
                <div className="text-[15px] font-medium">{s.title}</div>
                <div className="mt-1 text-[14px] text-white/50">{s.body}</div>
              </figcaption>
            </figure>
          ))}
        </div>
        <div className="pointer-events-none absolute inset-y-0 left-0 hidden w-16 bg-gradient-to-r from-bg to-transparent sm:block" />
        <div className="pointer-events-none absolute inset-y-0 right-0 hidden w-16 bg-gradient-to-l from-bg to-transparent sm:block" />
        <div className="absolute inset-x-0 top-[42%] flex -translate-y-1/2 justify-between px-1 sm:px-2">
          <button
            type="button"
            aria-label="Show previous app screen"
            onClick={() => scrollScreens(-1)}
            className="flex h-11 w-11 items-center justify-center rounded-full border border-white/15 bg-surface/95 text-white/75 shadow-lg shadow-black/30 backdrop-blur transition hover:border-accent/60 hover:bg-surface hover:text-white"
          >
            <LuArrowLeft className="h-5 w-5" />
          </button>
          <button
            type="button"
            aria-label="Show next app screen"
            onClick={() => scrollScreens(1)}
            className="flex h-11 w-11 items-center justify-center rounded-full border border-white/15 bg-surface/95 text-white/75 shadow-lg shadow-black/30 backdrop-blur transition hover:border-accent/60 hover:bg-surface hover:text-white"
          >
            <LuArrowRight className="h-5 w-5" />
          </button>
        </div>
      </div>
    </Section>
  )
}
