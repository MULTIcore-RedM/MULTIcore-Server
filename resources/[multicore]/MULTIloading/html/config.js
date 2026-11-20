// MULTIloading settings. Edit and restart the resource (players see it on their next join).
// The loading screen runs before any Lua, so its texts live here instead of locales/*.lua.
window.MULTILOADING = {
    // Language of the texts below: 'en', 'de', 'fr', 'es', 'pt-br', 'it', 'pl', 'ru', 'nl', 'tr'
    language: 'en',

    // Big title. A name passed with deferrals.handover({ name = '...' }) wins when useHandoverName is true.
    serverName: 'MULTIcore Server',
    // Use the handover name if a server script sends one
    useHandoverName: true,

    // Logo above the server name, in html/img/ (the MULTIcore logo by default); empty = no logo
    logo: 'img/mc-logo.png',

    // Optional background image in html/img/, e.g. 'img/background.jpg'; empty = plain black
    background: '',
    // Darkening over the background image, 0 (none) to 1 (black)
    backgroundShade: 0.45,

    // Seconds each tip stays
    tipSeconds: 8,
    // Tip fade-out before the next one shows (ms; match the transition in style.css)
    tipFadeMs: 400,
    // Shortest allowed tipSeconds
    tipMinSeconds: 3,

    // Texts per language (same keys in every language; English fills gaps)
    texts: {
        en: {
            subtitle: 'Roleplay in the year of our Lord 1899',
            tipLabel: 'Tip',
            loadingLabel: 'Loading',
            readyLabel: 'Preparing your arrival',
            mapLabel: 'map',
            tips: [
                'Speak to the townsfolk; most of them have work for an honest hand.',
                'Keep your horse fed and brushed and it will carry you further.',
                'Banks keep your money safe. Cash on your person can be lost.',
                'Read the server rules before you ride out.',
                'Use /logout to return to character select.',
            ],
        },
        de: {
            subtitle: 'Rollenspiel im Jahre des Herrn 1899',
            tipLabel: 'Tipp',
            loadingLabel: 'Lädt',
            readyLabel: 'Deine Ankunft wird vorbereitet',
            mapLabel: 'Karte',
            tips: [
                'Sprich mit den Leuten in der Stadt; viele haben Arbeit für eine ehrliche Hand.',
                'Füttere und striegle dein Pferd, dann trägt es dich weiter.',
                'Banken halten dein Geld sicher. Bargeld am Körper kann verloren gehen.',
                'Lies die Serverregeln, bevor du losreitest.',
                'Mit /logout kommst du zurück zur Charakterauswahl.',
            ],
        },
        fr: {
            subtitle: "Jeu de rôle en l'an de grâce 1899",
            tipLabel: 'Astuce',
            loadingLabel: 'Chargement',
            readyLabel: 'Préparation de votre arrivée',
            mapLabel: 'carte',
            tips: [
                'Parlez aux habitants ; beaucoup ont du travail pour une main honnête.',
                'Nourrissez et brossez votre cheval, il vous portera plus loin.',
                "Les banques gardent votre argent. L'argent sur vous peut être perdu.",
                'Lisez le règlement du serveur avant de partir.',
                'Utilisez /logout pour revenir à la sélection des personnages.',
            ],
        },
        es: {
            subtitle: 'Rol en el año del Señor de 1899',
            tipLabel: 'Consejo',
            loadingLabel: 'Cargando',
            readyLabel: 'Preparando tu llegada',
            mapLabel: 'mapa',
            tips: [
                'Habla con la gente del pueblo; muchos tienen trabajo para una mano honrada.',
                'Alimenta y cepilla a tu caballo y te llevará más lejos.',
                'Los bancos guardan tu dinero. El efectivo encima se puede perder.',
                'Lee las normas del servidor antes de salir.',
                'Usa /logout para volver a la selección de personaje.',
            ],
        },
        'pt-br': {
            subtitle: 'Roleplay no ano de Nosso Senhor de 1899',
            tipLabel: 'Dica',
            loadingLabel: 'Carregando',
            readyLabel: 'Preparando sua chegada',
            mapLabel: 'mapa',
            tips: [
                'Fale com o povo da cidade; muitos têm trabalho para mãos honestas.',
                'Alimente e escove seu cavalo e ele levará você mais longe.',
                'Bancos guardam seu dinheiro. Dinheiro no bolso pode ser perdido.',
                'Leia as regras do servidor antes de partir.',
                'Use /logout para voltar à seleção de personagem.',
            ],
        },
        it: {
            subtitle: "Gioco di ruolo nell'anno del Signore 1899",
            tipLabel: 'Consiglio',
            loadingLabel: 'Caricamento',
            readyLabel: 'Preparazione del tuo arrivo',
            mapLabel: 'mappa',
            tips: [
                'Parla con la gente del posto; molti hanno lavoro per una mano onesta.',
                'Nutri e striglia il tuo cavallo e ti porterà più lontano.',
                'Le banche custodiscono il tuo denaro. I contanti addosso si possono perdere.',
                'Leggi le regole del server prima di partire.',
                'Usa /logout per tornare alla selezione del personaggio.',
            ],
        },
        pl: {
            subtitle: 'Odgrywanie ról w roku Pańskim 1899',
            tipLabel: 'Wskazówka',
            loadingLabel: 'Wczytywanie',
            readyLabel: 'Przygotowujemy twój przyjazd',
            mapLabel: 'mapa',
            tips: [
                'Rozmawiaj z mieszkańcami; wielu ma pracę dla uczciwej ręki.',
                'Karm i czesz konia, a zaniesie cię dalej.',
                'Banki strzegą twoich pieniędzy. Gotówkę przy sobie można stracić.',
                'Przeczytaj zasady serwera, zanim ruszysz w drogę.',
                'Użyj /logout, aby wrócić do wyboru postaci.',
            ],
        },
        ru: {
            subtitle: 'Ролевая игра в лето Господне 1899',
            tipLabel: 'Совет',
            loadingLabel: 'Загрузка',
            readyLabel: 'Готовим ваше прибытие',
            mapLabel: 'карта',
            tips: [
                'Говорите с горожанами: у многих есть работа для честных рук.',
                'Кормите и чистите коня, и он унесёт вас дальше.',
                'Банк хранит ваши деньги. Наличные при себе можно потерять.',
                'Прочитайте правила сервера, прежде чем отправиться в путь.',
                'Команда /logout возвращает к выбору персонажа.',
            ],
        },
        nl: {
            subtitle: 'Rollenspel in het jaar onzes Heren 1899',
            tipLabel: 'Tip',
            loadingLabel: 'Laden',
            readyLabel: 'Je aankomst wordt voorbereid',
            mapLabel: 'kaart',
            tips: [
                'Praat met de dorpelingen; velen hebben werk voor een eerlijke hand.',
                'Voer en borstel je paard en het brengt je verder.',
                'Banken bewaren je geld veilig. Contant geld op zak kun je kwijtraken.',
                'Lees de serverregels voordat je op pad gaat.',
                'Met /logout ga je terug naar de personagekeuze.',
            ],
        },
        tr: {
            subtitle: "Rabbimizin 1899 yılında rol yapma",
            tipLabel: 'İpucu',
            loadingLabel: 'Yükleniyor',
            readyLabel: 'Varışın hazırlanıyor',
            mapLabel: 'harita',
            tips: [
                'Kasabalılarla konuş; çoğunun dürüst bir el için işi var.',
                'Atını besle ve tımarla, seni daha uzağa taşır.',
                'Bankalar paranı korur. Üzerindeki nakit kaybolabilir.',
                'Yola çıkmadan önce sunucu kurallarını oku.',
                'Karakter seçimine dönmek için /logout kullan.',
            ],
        },
    },
};
