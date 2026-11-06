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
    rail.current?.scrollBy({ left: direction * (rail.current.clientWidth * 0.8), behavior: "smooth" })
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
        <div className="pointer-events-none absolute inset-y-0 right-0 hidden w-28 bg-gradient-to-l from-bg via-bg/70 to-transparent sm:block" />
        <div className="absolute right-4 top-0 flex items-center gap-2">
          <button
            type="button"
            aria-label="Show previous app screen"
            onClick={() => scrollScreens(-1)}
            className="flex h-9 w-9 items-center justify-center rounded-full border border-white/10 bg-bg/90 text-white/70 backdrop-blur transition hover:border-white/25 hover:text-white"
          >
            <LuArrowLeft className="h-4 w-4" />
          </button>
          <button
            type="button"
            aria-label="Show next app screen"
            onClick={() => scrollScreens(1)}
            className="flex h-9 w-9 items-center justify-center rounded-full border border-white/10 bg-bg/90 text-white/70 backdrop-blur transition hover:border-white/25 hover:text-white"
          >
            <LuArrowRight className="h-4 w-4" />
          </button>
        </div>
      </div>
    </Section>
  )
}
