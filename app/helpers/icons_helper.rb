# The app's own icons, in place of emojis, so they look the same on every device and match the logo: drawn on a
# 24 × 24 grid, in the logo's neon colours where they have a colour of their own, otherwise in the text's colour.
# icon(:flame) for one beside some words, which is hidden from screen readers as the words say it; give it a
# label when it stands alone. Plain text (shared results, notifications, menus) keeps emojis, as it has to
module IconsHelper
  # Lines in the text's colour, rounded like the wordmark
  LINE = %(fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round")
  STAR = "M12 2.6l2.85 5.9 6.45.85-4.7 4.5 1.17 6.4L12 17.17 6.23 20.25l1.17-6.4-4.7-4.5 6.45-.85z"

  ICONS = {
    # The game
    gem: %(<path d="M7 3.5h10l4.5 5.5L12 21 2.5 9z" fill="var(--blue)"/><path d="M2.5 9h19M9.5 3.5 8 9l4 12 4-12-1.5-5.5" fill="none" stroke="var(--blue-deep)" stroke-width="1.3" stroke-linejoin="round"/>),
    # A star earned is solid blue, outlined in the same blue so it's the same size as one still to earn, in grey
    star: %(<path d="#{STAR}" fill="var(--blue)" stroke="var(--blue)" stroke-width="1.6" stroke-linejoin="round"/>),
    star_empty: %(<path d="#{STAR}" fill="none" stroke="color-mix(in srgb, var(--ink) 35%, transparent)" stroke-width="1.6" stroke-linejoin="round"/>),
    flame: %(<path d="M12 2.5c.6 3.4 5.5 5.6 5.5 11a5.5 5.5 0 0 1-11 0c0-2.6 1.4-4.4 2.6-6 .2 1.8 1 2.8 2 3.2-.4-3 .1-5.8.9-8.2z" fill="var(--pink)"/><path d="M12 12.5c.8 1.6 2.6 2.4 2.6 4.4a2.6 2.6 0 0 1-5.2 0c0-1.3.8-2.2 1.4-3 .2.8.6 1.2 1.1 1.4-.1-1 0-1.9.1-2.8z" fill="var(--yellow)"/>),
    # Gold with a brown outline in light mode, where neon yellow is hard to see; neon yellow in dark mode
    trophy: %(<g fill="var(--trophy, var(--yellow))" stroke="var(--trophy-outline, transparent)" stroke-width="1.2" stroke-linejoin="round" paint-order="stroke"><path d="M6 3h12v5a6 6 0 0 1-12 0z"/><path d="M6 5H3v1.5A4.5 4.5 0 0 0 7 11V9a2.5 2.5 0 0 1-2-2.5V7h1zM18 5h3v1.5A4.5 4.5 0 0 1 17 11V9a2.5 2.5 0 0 0 2-2.5V7h-1z"/><rect x="10.75" y="13" width="2.5" height="4"/><rect x="7" y="17" width="10" height="3.5" rx="1"/></g>),
    freeze: %(<path d="M12 2.5v19M3.8 7.25l16.4 9.5M3.8 16.75l16.4-9.5M9.5 4.2 12 6.5l2.5-2.3M9.5 19.8 12 17.5l2.5 2.3" fill="none" stroke="var(--blue)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>),
    review: %(<path d="M19.5 10.5A7.5 7.5 0 0 0 6.2 6.6L4 9M4.5 13.5a7.5 7.5 0 0 0 13.3 3.9L20 15" #{LINE}/><path d="M4 4.5V9h4.5M20 19.5V15h-4.5" #{LINE}/>),
    mixed: %(<path d="M3 7h3.5c4.5 0 6.5 10 11 10H21M3 17h3.5c1.6 0 2.8-1.3 3.8-3M13.7 10c1-1.7 2.2-3 3.8-3H21" #{LINE}/><path d="M18 4l3 3-3 3M18 14l3 3-3 3" #{LINE}/>),
    book: %(<path d="M12 6.5C9.5 4.5 6 4.2 3 5v13.5c3-.8 6.5-.5 9 1.5 2.5-2 6-2.3 9-1.5V5c-3-.8-6.5-.5-9 1.5zM12 6.5V20" #{LINE}/>),
    bulb: %(<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.6 10.8c.7.6 1.1 1.4 1.1 2.2h5c0-.8.4-1.6 1.1-2.2A6 6 0 0 0 12 3z" #{LINE}/>),
    # Zzz: right, but sleepy
    slow: %(<path d="M2.5 11h7l-7 9.5h7M12 5.5h5.5L12 13h5.5M18.5 1.8h3.5l-3.5 4.7H22" #{LINE}/>),
    bell: %(<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15zM10 21h4" #{LINE}/>),
    # Two swords crossed, in the two players' colours
    versus: %(<path d="M4 4l11 11M12.5 17.5l5-5M16 16l4 4" fill="none" stroke="var(--blue)" stroke-width="2.4" stroke-linecap="round"/><path d="M20 4 9 15M6.5 12.5l5 5M8 16l-4 4" fill="none" stroke="var(--pink)" stroke-width="2.4" stroke-linecap="round"/>),
    people: %(<circle cx="8" cy="7.5" r="3.5" fill="var(--pink)"/><path d="M1.5 20a6.5 6.5 0 0 1 13 0z" fill="var(--pink)"/><circle cx="16.5" cy="8.5" r="3" fill="var(--green)"/><path d="M12.5 20a5.5 5.5 0 0 1 10-1.5V20z" fill="var(--green)"/>),
    check: %(<circle cx="12" cy="12" r="9.5" fill="var(--green)"/><path d="M7.5 12.3l3 3 6-6.3" fill="none" stroke="var(--on-neon, #1d1e17)" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>),
    party: %(<path d="M3 21l4.5-12.5 8 8z" fill="var(--yellow)"/><path d="M13 3.5c.6 1.6 0 3-1.5 3.8M20.5 11c-1.6-.6-3 0-3.8 1.5M16.5 4.5l.5-1.5M19.5 7.5 21 7M18 9l1-1" fill="none" stroke="var(--pink)" stroke-width="2" stroke-linecap="round"/><circle cx="14" cy="9.5" r="1.2" fill="var(--blue)"/><circle cx="20" cy="15.5" r="1.2" fill="var(--green)"/>),
    level_up: %(<circle cx="12" cy="12" r="9.5" fill="var(--blue)"/><path d="M12 17V7.5M7.5 11.5 12 7l4.5 4.5" fill="none" stroke="var(--on-neon, #1d1e17)" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>),
    phone: %(<rect x="6" y="2.5" width="12" height="19" rx="2.5" #{LINE}/><path d="M12 7v7M9 11l3 3 3-3" #{LINE}/>),
    target: %(<circle cx="12" cy="12" r="9.5" fill="var(--pink)"/><circle cx="12" cy="12" r="6.2" fill="var(--paper, #fff)"/><circle cx="12" cy="12" r="3" fill="var(--pink)"/>),
    lightning: %(<path d="M13.5 2 4.5 13.5H11L9.5 22l9-11.5H12z" fill="var(--yellow)" stroke="color-mix(in srgb, var(--ink) 35%, transparent)" stroke-width="1" stroke-linejoin="round"/>),
    rocket: %(<path d="M12 2.5c3.5 2.5 5 6.3 4.5 11.5h-9C7 8.8 8.5 5 12 2.5z" fill="var(--blue)"/><circle cx="12" cy="9.5" r="1.8" fill="var(--paper, #fff)"/><path d="M7.5 11 4.5 15.5 7.5 15zM16.5 11l3 4.5-3-.5z" fill="var(--pink)"/><path d="M10 16.5c0 2 1 3.5 2 5 1-1.5 2-3 2-5" fill="var(--yellow)"/>),
    comeback: %(<path d="M4 15a8 8 0 1 1 3 5.5" #{LINE}/><path d="M4 21v-6h6" #{LINE}/><path d="M12 8v4l3 2" #{LINE}/>),
    rainbow: %(<path d="M2.5 18a9.5 9.5 0 0 1 19 0" fill="none" stroke="var(--pink)" stroke-width="2.6"/><path d="M5.5 18a6.5 6.5 0 0 1 13 0" fill="none" stroke="var(--yellow)" stroke-width="2.6"/><path d="M8.5 18a3.5 3.5 0 0 1 7 0" fill="none" stroke="var(--blue)" stroke-width="2.6"/>),
    perfect: %(<circle cx="12" cy="10" r="7.5" fill="var(--green)"/><path d="M8.5 16.5 6.5 22l5.5-2.5L17.5 22l-2-5.5" fill="var(--green)"/><path d="M8.7 10.2l2.2 2.2 4.4-4.6" fill="none" stroke="var(--on-neon, #1d1e17)" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>),
    lock: %(<path fill="currentColor" fill-rule="evenodd" clip-rule="evenodd" d="M12 1.5a5.25 5.25 0 0 0-5.25 5.25v3a3 3 0 0 0-3 3v6.75a3 3 0 0 0 3 3h10.5a3 3 0 0 0 3-3v-6.75a3 3 0 0 0-3-3v-3c0-2.9-2.35-5.25-5.25-5.25Zm3.75 8.25v-3a3.75 3.75 0 1 0-7.5 0v3h7.5Z"/>),
    home: %(<rect x="5" y="11" width="14" height="10" fill="var(--blue)"/><path d="M2.5 12 12 3l9.5 9z" fill="var(--blue)"/>),
    stats: %(<rect x="3" y="12" width="5" height="9" rx="1.5" fill="var(--pink)"/><rect x="9.5" y="7" width="5" height="14" rx="1.5" fill="var(--green)"/><rect x="16" y="3" width="5" height="18" rx="1.5" fill="var(--blue)"/>),
    # Error pages
    question: %(<circle cx="12" cy="12" r="9.5" #{LINE}/><path d="M9.2 9.3a3 3 0 0 1 5.8 1c0 2-3 2.5-3 4.2M12 17.6v.1" #{LINE}/>),
    search: %(<circle cx="10.5" cy="10.5" r="6.5" #{LINE}/><path d="M15.5 15.5 21 21" #{LINE}/>),
    oops: %(<path d="M12 3 2.5 20h19z" #{LINE}/><path d="M12 10v4.5M12 17.4v.1" #{LINE}/>),
    # Topics
    addition: %(<path d="M12 4.5v15M4.5 12h15" #{LINE} stroke-width="3"/>),
    times_tables: %(<path d="M6 6l12 12M18 6 6 18" #{LINE} stroke-width="3"/>),
    division: %(<path d="M5 12h14" #{LINE} stroke-width="3"/><circle cx="12" cy="6" r="2" fill="currentColor"/><circle cx="12" cy="18" r="2" fill="currentColor"/>),
    negatives: %(<path d="M14.5 13.5V5a2.5 2.5 0 0 0-5 0v8.5a4.5 4.5 0 1 0 5 0z" #{LINE}/><circle cx="12" cy="17" r="2.2" fill="var(--blue)"/><path d="M12 17v-6" stroke="var(--blue)" stroke-width="2.2" stroke-linecap="round"/>),
    fractions: %(<circle cx="12" cy="12" r="9.5" #{LINE}/><path d="M12 12V2.5A9.5 9.5 0 0 1 21.5 12z" fill="var(--pink)"/>),
    percentages: %(<path d="M18.5 5.5l-13 13" #{LINE} stroke-width="2.6"/><circle cx="7" cy="7" r="2.6" #{LINE}/><circle cx="17" cy="17" r="2.6" #{LINE}/>),
    conversions: %(<rect x="2" y="7.5" width="20" height="9" rx="1.5" #{LINE}/><path d="M6 7.5V11M10 7.5v5M14 7.5V11M18 7.5v5" #{LINE}/>),
    equations: %(<path d="M12 3.5v17M7.5 20.5h9M4 6.5h16M4 6.5l-2.5 6a3 3 0 0 0 5 0zM20 6.5l-2.5 6a3 3 0 0 0 5 0z" #{LINE}/>),
    # A cog: a ring with eight square teeth
    functions: %(<circle cx="12" cy="12" r="6.6" fill="none" stroke="currentColor" stroke-width="2.6"/><circle cx="12" cy="12" r="2.2" fill="currentColor"/><path d="M12 6V2.4M16.24 7.76l2.55-2.55M18 12h3.6M16.24 16.24l2.55 2.55M12 18v3.6M7.76 16.24l-2.55 2.55M6 12H2.4M7.76 7.76 5.21 5.21" fill="none" stroke="currentColor" stroke-width="3.4" stroke-linecap="butt"/>),
    simultaneous: %(<path d="M3 19 21 7M3 9l18 8" #{LINE}/><circle cx="12" cy="13" r="2.4" fill="var(--pink)"/>)
  }.freeze

  def icon(name, label: nil, class: nil)
    tag.svg(ICONS.fetch(name).html_safe, viewBox: "0 0 24 24", class: [ "icon", "icon--#{name}", binding.local_variable_get(:class) ],
      role: ("img" if label), aria: { label: label, hidden: ("true" unless label) }, focusable: "false")
  end

  # A topic's own icon, named for its key
  def topic_icon(topic, **options)
    icon(topic.key.to_sym, **options)
  end

  # 1 to 3 of a level's stars, filled for those earned: the level's rating
  def star_rating(earned, out_of: 3, label: true)
    tag.span(class: "stars", role: ("img" if label), aria: { label: ("#{earned} of #{out_of} stars" if label) }) do
      safe_join(Array.new(out_of) { |i| icon(i < earned ? :star : :star_empty) })
    end
  end
end
