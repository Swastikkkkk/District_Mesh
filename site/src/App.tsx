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
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reduceMotion) return

    gsap.utils.toArray<HTMLElement>(".reveal").forEach(el => {
      gsap.fromTo(el,
        { y: 34, opacity: 0, rotateX: 4, transformOrigin: "center bottom" },
        { y: 0, opacity: 1, rotateX: 0, duration: 0.9, ease: "power3.out", scrollTrigger: { trigger: el, start: "top 88%", once: true } },
      )
    })

    gsap.utils.toArray<HTMLElement>(".section-heading").forEach(heading => {
      gsap.fromTo(heading,
        { y: 24, opacity: 0 },
        { y: 0, opacity: 1, duration: 1, ease: "power3.out", scrollTrigger: { trigger: heading, start: "top 84%", once: true } },
      )
    })

    gsap.utils.toArray<HTMLElement>(".section-content").forEach(content => {
      gsap.fromTo(content,
        { y: 18 },
        { y: 0, ease: "none", scrollTrigger: { trigger: content, start: "top bottom", end: "top 40%", scrub: 1.2 } },
      )
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
