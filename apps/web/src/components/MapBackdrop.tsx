// Placeholder for the full-screen map behind every sheet (MapLibre arrives in step 6). Dark-blue "sea" with soft
// land masses so the sheet-over-map composition is visible now.
export function MapBackdrop() {
  return (
    <div className="map-backdrop" aria-hidden="true">
      <svg viewBox="0 0 400 800" preserveAspectRatio="xMidYMin slice">
        <defs>
          <radialGradient id="sea" cx="50%" cy="25%" r="80%">
            <stop offset="0" stopColor="#173a7a" />
            <stop offset="1" stopColor="#0a1a40" />
          </radialGradient>
        </defs>
        <rect width="400" height="800" fill="url(#sea)" />
        <path d="M-20 120c40-30 90-20 120 10 20 25 5 60-20 80-40 25-60 70-100 40z" fill="#2f6f5d" opacity=".85" />
        <path d="M170 60c30-25 80-10 110 15 40 30 100 20 130 50v120c-50 25-90-10-130-5-40 5-70 40-110 10-30-20-10-60-20-90s-20-55 20-100z" fill="#3d7d63" opacity=".85" />
        <path d="M120 270c30 10 60 40 55 80s-40 70-60 100c-15-30-45-60-40-100s15-65 45-80z" fill="#2c6a58" opacity=".8" />
        <path d="M60 330 L150 220 L260 300" fill="none" stroke="#5aa2ff" strokeWidth="2.5" strokeLinecap="round" />
        <circle cx="60" cy="330" r="5" fill="#9ccaff" stroke="#5aa2ff" strokeWidth="2" />
        <circle cx="260" cy="300" r="5" fill="#9ccaff" stroke="#5aa2ff" strokeWidth="2" />
      </svg>
    </div>
  );
}
