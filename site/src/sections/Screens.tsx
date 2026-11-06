import { Phone } from "@/components/Phone"
import { Section } from "@/components/Section"
import { asset } from "@/lib/site"

const shots = [
  { file: "onboarding", title: "Meet NoBars", body: "No network, no towers, works in Airplane Mode." },
  { file: "walkthrough", title: "Go live", body: "One tap and your phone starts finding your group." },
  { file: "home", title: "Your crew at a glance", body: "Who's nearby, call buttons and chat in one place." },
  { file: "map", title: "Find each other", body: "Buddies on the map, SOS in red." },
]

export function Screens() {
  return (
    <Section id="screens" eyebrow="Screens" title="Straight from the app."
      intro="Real screenshots from two simulators meshed together, captured automatically on every build.">
      <div className="-mx-5 flex snap-x snap-mandatory gap-6 overflow-x-auto px-5 pb-6 sm:-mx-8 sm:px-8 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {shots.map(s => (
          <figure key={s.file} className="reveal w-[220px] shrink-0 snap-start sm:w-[240px]">
            <Phone src={asset(`shots/${s.file}.webp`)} alt={s.title} />
            <figcaption className="mt-5 px-1">
              <div className="text-[15px] font-medium">{s.title}</div>
              <div className="mt-1 text-[14px] text-white/50">{s.body}</div>
            </figcaption>
          </figure>
        ))}
      </div>
    </Section>
  )
}
