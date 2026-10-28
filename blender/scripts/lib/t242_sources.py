"""Obras de domínio público usadas nas pinturas da T-242 (ukiyo-e e biombos de verdade, sem IA).

Cada fonte: arquivo local, link da imagem, página da obra e a licença conferida no acervo (campo da API do museu:
The Met `isPublicDomain: true` = Open Access CC0; Cleveland Museum of Art `share_license_status: CC0`).
O arquivo original NÃO vai para o Git (pode ter dezenas de MB): fica em `blender/renders/t242/fontes/` (baixado por
`python -I tools/fetch_t242_sources.py`) ou em `docs/Murais/` (imagens que o Marco colocar). O build procura nas duas.
Só biblioteca padrão (lido também pelo Python do sistema).
"""
from __future__ import annotations

MET = "The Metropolitan Museum of Art (Open Access, CC0)"
CMA = "Cleveland Museum of Art (Open Access, CC0)"

# chave: (arquivo, url da imagem, página, artista, título, data, acervo, número do objeto)
SOURCES = {
    # --- tigres -----------------------------------------------------------------------------------------------
    "sekkei_tigers": ("cma_1972.10.jpg", "https://openaccess-cdn.clevelandart.org/1972.10/1972.10_print.jpg",
                      "https://clevelandart.org/art/1972.10", "Yamaguchi Sekkei (1644–1732)",
                      "Lions and Tigers in Peony and Bamboo (par de biombos; usamos o dos tigres)", "1668", CMA, "1972.10"),
    "soga_tiger": ("cma_1985.134.2.jpg", "https://openaccess-cdn.clevelandart.org/1985.134.2/1985.134.2_print.jpg",
                   "https://clevelandart.org/art/1985.134.2", "Soga Nichokuan (ativo c. 1625–1660)", "Tiger (biombo)",
                   "early to mid-1600s", CMA, "1985.134.2"),
    "ganku_family_r": ("cma_1983.3.1.jpg", "https://openaccess-cdn.clevelandart.org/1983.3.1/1983.3.1_print.jpg",
                       "https://clevelandart.org/art/1983.3.1", "Kishi Ganku (1749/56–1838)",
                       "Tiger Family (biombo da direita do par)", "early 1800s", CMA, "1983.3.1"),
    "ganku_family_l": ("cma_1983.3.2.jpg", "https://openaccess-cdn.clevelandart.org/1983.3.2/1983.3.2_print.jpg",
                       "https://clevelandart.org/art/1983.3.2", "Kishi Ganku (1749/56–1838)",
                       "Tiger Family (biombo da esquerda do par)", "early 1800s", CMA, "1983.3.2"),
    "ganku_tiger": ("met_49063.jpg", "https://images.metmuseum.org/CRDImages/as/original/36_100_11_O2.jpg",
                    "https://www.metmuseum.org/art/collection/search/49063", "Kishi Ganku (1749–1838)",
                    "Tiger (rolo vertical)", "early 19th century", MET, "36.100.11"),
    # --- kabuki (Sharaku, 1794) -------------------------------------------------------------------------------
    "sharaku_omezo": ("met_36673.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP130177.jpg",
                      "https://www.metmuseum.org/art/collection/search/36673", "Tōshūsai Sharaku",
                      "Ichikawa Omezō I as Yakko Ippei", "1794", MET, "JP196"),
    "sharaku_hikosaburo": ("met_37359.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP130229.jpg",
                           "https://www.metmuseum.org/art/collection/search/37359", "Tōshūsai Sharaku",
                           "Bandō Hikosaburō III as Sagisaka Sanai", "1794", MET, "JP2823"),
    "sharaku_komazo": ("met_37352.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP130222.jpg",
                       "https://www.metmuseum.org/art/collection/search/37352", "Tōshūsai Sharaku",
                       "Ichikawa Komazō III as Shiga Daishichi", "1794", MET, "JP2649"),
    "sharaku_ebizo": ("met_37368.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP130194.jpg",
                      "https://www.metmuseum.org/art/collection/search/37368", "Tōshūsai Sharaku",
                      "Ichikawa Ebizō (Danjūrō V) as Takemura Sadanoshin", "1794", MET, "JP3114"),
    "sharaku_hangoro": ("met_37331.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP130188.jpg",
                        "https://www.metmuseum.org/art/collection/search/37331", "Tōshūsai Sharaku",
                        "Sakata Hangorō III as Fujikawa Mizuemon", "1794", MET, "JP1522"),
    "sharaku_mitsugoro": ("met_37367.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP130249.jpg",
                          "https://www.metmuseum.org/art/collection/search/37367", "Tōshūsai Sharaku",
                          "Bandō Mitsugorō II as Ishii Genzō", "ca. 1794", MET, "JP3113"),
    "sharaku_oniji": ("met_37358.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP130228.jpg",
                      "https://www.metmuseum.org/art/collection/search/37358", "Tōshūsai Sharaku",
                      "Ōtani Oniji III as Yakko Edobei", "1794", MET, "JP2822"),
    # --- bijin-ga ---------------------------------------------------------------------------------------------
    "utamaro_courtesan": ("met_40601.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP135592.jpg",
                          "https://www.metmuseum.org/art/collection/search/40601", "Kitagawa Utamaro",
                          "A Courtesan", "c. 1790s", MET, "JP1663"),
    "utamaro_parasol": ("met_55319.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP141292.jpg",
                        "https://www.metmuseum.org/art/collection/search/55319", "Kitagawa Utamaro",
                        "Woman Holding Up a Parasol (Ten Classes of Women's Physiognomy)", "ca. 1792–93", MET, "JP2730"),
    "utamaro_konosumi": ("met_53689.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP135598.jpg",
                         "https://www.metmuseum.org/art/collection/search/53689", "Kitagawa Utamaro",
                         "The Courtesan Konosumi (Beauties of the Southern Quarter)", "ca. 1793–94", MET, "JP1367"),
    "utamaro_ise": ("met_37340.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP144590.jpg",
                    "https://www.metmuseum.org/art/collection/search/37340", "Kitagawa Utamaro",
                    "Women Worshipping the Rising Sun between the Twin Rocks at Ise (tríptico)", "c. 1790s", MET, "JP1680"),
    "kuniyoshi_autumn": ("met_56684.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP146825.jpg",
                         "https://www.metmuseum.org/art/collection/search/56684", "Utagawa Kuniyoshi",
                         "Autumn, from Women's Pleasures of the Four Seasons (tríptico)", "ca. 1844–46", MET, "JP3136"),
    "utamaro_fireflies": ("met_36630.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP144584.jpg",
                          "https://www.metmuseum.org/art/collection/search/36630", "Kitagawa Utamaro",
                          "Catching Fireflies (Hotaru gari) (tríptico)", "ca. 1796–97", MET, "JP151"),
    "utamaro_hanaogi": ("met_53654.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP141287.jpg",
                        "https://www.metmuseum.org/art/collection/search/53654", "Kitagawa Utamaro",
                        "Hanaōgi of the Gomeirō (Comparing the Charms of Beauties)", "ca. 1794–95", MET, "JP1676"),
    # --- guerreiros -------------------------------------------------------------------------------------------
    "yoshitoshi_masakiyo": ("met_72829.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP147714.jpg",
                            "https://www.metmuseum.org/art/collection/search/72829", "Tsukioka Yoshitoshi",
                            "Masakiyo's Challenging Battle, from Taiheiki (tríptico)", "1866", MET, "2005.351a–c"),
    "kuniyoshi_shotoku": ("met_893319.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP149160.jpg",
                          "https://www.metmuseum.org/art/collection/search/893319", "Utagawa Kuniyoshi",
                          "Shōtoku Taishi Destroying Mononobe no Moriya (tríptico)", "1852", MET, "JP1115.3a–c"),
    "kunisada_awazu": ("met_893321.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP149162.jpg",
                       "https://www.metmuseum.org/art/collection/search/893321", "Utagawa Kunisada",
                       "Battle of Awazugahara (tríptico)", "mid-19th century", MET, "JP1115.5a–c"),
}


def info(key: str) -> dict:
    f, url, page, artist, title, date, museum, objnum = SOURCES[key]
    return {"file": f, "url": url, "page": page, "artist": artist, "title": title, "date": date, "museum": museum,
            "object": objnum}
