// Current state
let currentSlide = 0;
let currentLang = 'en';

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
    updateLanguage('en');
    showSlide(0);
});

// Setup event listeners
function setupEventListeners() {
    // Language buttons
    document.querySelectorAll('.lang-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const lang = e.target.dataset.lang;
            updateLanguage(lang);
        });
    });
    
    
    // Keyboard navigation
    document.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowLeft') {
            changeSlide(-1);
        } else if (e.key === 'ArrowRight') {
            changeSlide(1);
        }
    });
}

// Change slide
function changeSlide(direction) {
    const slides = document.querySelectorAll('.slide');
    const newSlide = (currentSlide + direction + slides.length) % slides.length;
    showSlide(newSlide);
}

// Show specific slide
function showSlide(index) {
    const slides = document.querySelectorAll('.slide');
    
    // Hide all slides
    slides.forEach(slide => slide.classList.remove('active'));
    
    // Show selected slide
    slides[index].classList.add('active');
    
    currentSlide = index;
}

// Update language
function updateLanguage(lang) {
    currentLang = lang;
    
    // Update active language button
    document.querySelectorAll('.lang-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.lang === lang) {
            btn.classList.add('active');
        }
    });
    
    // Update all text elements
    document.querySelectorAll('[data-i18n]').forEach(element => {
        const key = element.dataset.i18n;
        if (translations[lang] && translations[lang][key]) {
            element.innerHTML = translations[lang][key];
        }
    });
    
    // Update HTML lang attribute
    document.documentElement.lang = lang;
}

// Auto-play video when visible
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        const video = entry.target.querySelector('video');
        if (video) {
            if (entry.isIntersecting) {
                video.play();
            } else {
                video.pause();
            }
        }
    });
});

document.querySelectorAll('.slide').forEach(slide => {
    observer.observe(slide);
});