import { Phone } from "@/components/Phone"
import { Section } from "@/components/Section"
import { asset } from "@/lib/site"

const shots = [
  { file: "onboarding", title: "Pick a name and group", body: "Two fields and you're in." },
  { file: "home", title: "Your crew at a glance", body: "Who's nearby, and chat in one place." },
  { file: "chat", title: "Chat with no signal", body: "Messages hop through other phones." },
  { file: "sos", title: "SOS in one tap", body: "Your location goes out to everyone." },
  { file: "map", title: "Find each other", body: "Buddies on the map, SOS in red." },
  { file: "walkthrough", title: "Quick walkthrough", body: "Learn the basics in a few swipes." },
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
