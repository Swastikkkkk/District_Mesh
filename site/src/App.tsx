import { useRef } from "react"
import gsap from "gsap"
import { ScrollTrigger } from "gsap/ScrollTrigger"
import { useGSAP } from "@gsap/react"
import { StarsBackground } from "@/components/ui/stars-background"
import { ShootingStars } from "@/components/ui/shooting-stars"
import { Nav } from "@/sections/Nav"
import { Hero } from "@/sections/Hero"
import { HowItWorks } from "@/sections/HowItWorks"
import { Features } from "@/sections/Features"
import { Screens } from "@/sections/Screens"
import { Install } from "@/sections/Install"
import { Faq } from "@/sections/Faq"
import { Footer } from "@/sections/Footer"

gsap.registerPlugin(ScrollTrigger)

export default function App() {
  const root = useRef<HTMLDivElement>(null)
  useGSAP(() => {
    gsap.utils.toArray<HTMLElement>(".reveal").forEach(el => {
      gsap.from(el, { y: 28, opacity: 0, duration: 0.9, ease: "power3.out", scrollTrigger: { trigger: el, start: "top 88%", once: true } })
    })
  }, { scope: root })

  return (
    <div ref={root} className="relative min-h-screen overflow-x-hidden">
      <div className="pointer-events-none fixed inset-0 z-0">
        <StarsBackground starDensity={0.00012} />
        <ShootingStars starColor="#ffffff" trailColor="#b49cff" minDelay={2500} maxDelay={6000} />
      </div>
      <div className="relative z-10">
        <Nav />
        <main>
          <Hero />
          <HowItWorks />
          <Features />
          <Screens />
          <Install />
          <Faq />
        </main>
        <Footer />
      </div>
    </div>
  )
}
