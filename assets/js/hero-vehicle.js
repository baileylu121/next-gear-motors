function syncHeroVehicle() {
  const hero = document.querySelector("#hero-stock");
  if (!hero) return;

  const slides = Array.from(hero.querySelectorAll(".slide"));
  const active = slides.findIndex((slide) =>
    slide.classList.contains("active-slide"),
  );
  const index = active === -1 ? 1 : active + 1;

  document.querySelectorAll("[data-hero-vehicle]").forEach((link) => {
    const match = link.getAttribute("data-hero-vehicle") === String(index);
    link.classList.toggle("hidden", !match);
  });
}

const heroObserver = new MutationObserver(syncHeroVehicle);

function watchHero() {
  const hero = document.querySelector("#hero-stock");
  if (!hero) return;
  syncHeroVehicle();
  heroObserver.observe(hero, {
    subtree: true,
    attributes: true,
    attributeFilter: ["class"],
  });
}

watchHero();
