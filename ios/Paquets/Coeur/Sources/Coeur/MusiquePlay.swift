// Les morceaux que la version Play livre (MusiquePlay.kt) : la seule liste qu'iOS livre, la liste « hors
// Play » étant vide pour elle (src/musique_play/MusiqueHorsPlay.kt, PUBLICATION_PLAY_STORE.md § 3.2). La table
// est recopiée par programme du Kotlin, dans le même ordre : les nouveaux vont en fin de liste, le
// morceau par défaut ne change pas. Les ressources d'Android y sont nommées : `rawRes` est le nom du
// fichier livré (`Musique/<rawRes>.m4a` dans musique.json), `titleRes` la clé de son titre.

/// Les morceaux livrés avec l'application.
public enum MusiquePlay {

    /// Un morceau livré (Bundled de MusiquePlay.kt) : son identifiant, son fichier et la clé de son titre.
    public struct Bundled: Sendable, Hashable {
        public let id: String
        /// Le nom de la ressource audio (R.raw.x d'Android), qui est aussi celui du fichier d'iOS.
        public let rawRes: String
        /// La clé du titre dans le catalogue (R.string.x d'Android).
        public let titleRes: String

        public init(id: String, rawRes: String, titleRes: String) {
            self.id = id
            self.rawRes = rawRes
            self.titleRes = titleRes
        }
    }

    /// MORCEAUX, dans l'ordre du Kotlin : le premier est le morceau par défaut.
    public static let morceaux: [Bundled] = [
        Bundled(id: "hamelech_basade", rawRes: "hamelech_basade", titleRes: "track_hamelech_basade"),
        Bundled(id: "yanuka_nigoun_3", rawRes: "yanuka_nigoun_3", titleRes: "track_yanuka_nigoun_3"),
        Bundled(id: "shpayer_beyond", rawRes: "shpayer_beyond", titleRes: "track_shpayer_beyond"),
        Bundled(id: "shpayer_eshet_hayil", rawRes: "shpayer_eshet_hayil", titleRes: "track_shpayer_eshet_hayil"),
        Bundled(id: "shpayer_arba_bavot", rawRes: "shpayer_arba_bavot", titleRes: "track_shpayer_arba_bavot"),
        Bundled(id: "shpayer_afilou", rawRes: "shpayer_afilou", titleRes: "track_shpayer_afilou"),
        Bundled(id: "shpayer_kenout", rawRes: "shpayer_kenout", titleRes: "track_shpayer_kenout"),
        Bundled(id: "shpayer_esh_kamanche", rawRes: "shpayer_esh_kamanche", titleRes: "track_shpayer_esh_kamanche"),
        Bundled(id: "shpayer_hithadshout", rawRes: "shpayer_hithadshout", titleRes: "track_shpayer_hithadshout"),
        Bundled(id: "shpayer_pnima", rawRes: "shpayer_pnima", titleRes: "track_shpayer_pnima"),
        Bundled(id: "shpayer_tunnels_end", rawRes: "shpayer_tunnels_end", titleRes: "track_shpayer_tunnels_end"),
        Bundled(id: "shpayer_ki_hine_kahomer", rawRes: "shpayer_ki_hine_kahomer", titleRes: "track_shpayer_ki_hine_kahomer"),
        Bundled(id: "ianir_mirage", rawRes: "ianir_mirage", titleRes: "track_ianir_mirage"),
        Bundled(id: "ianir_al_harega", rawRes: "ianir_al_harega", titleRes: "track_ianir_al_harega"),
        Bundled(id: "ianir_hello", rawRes: "ianir_hello", titleRes: "track_ianir_hello"),
        Bundled(id: "ianir_baal_shem_tov", rawRes: "ianir_baal_shem_tov", titleRes: "track_ianir_baal_shem_tov"),
        Bundled(id: "ianir_zemer_bishvahin", rawRes: "ianir_zemer_bishvahin", titleRes: "track_ianir_zemer_bishvahin"),
        Bundled(id: "ianir_berditchev", rawRes: "ianir_berditchev", titleRes: "track_ianir_berditchev"),
        Bundled(id: "ianir_kol_bayaar", rawRes: "ianir_kol_bayaar", titleRes: "track_ianir_kol_bayaar"),
        Bundled(id: "ianir_yohanan_hasandlar", rawRes: "ianir_yohanan_hasandlar", titleRes: "track_ianir_yohanan_hasandlar"),
        Bundled(id: "ianir_haleluhu", rawRes: "ianir_haleluhu", titleRes: "track_ianir_haleluhu"),
        Bundled(id: "ianir_houppa", rawRes: "ianir_houppa", titleRes: "track_ianir_houppa"),
        Bundled(id: "ianir_eden_el_salvador", rawRes: "ianir_eden_el_salvador", titleRes: "track_ianir_eden_el_salvador"),
        Bundled(id: "ianir_hakol_milfanekha", rawRes: "ianir_hakol_milfanekha", titleRes: "track_ianir_hakol_milfanekha"),
        Bundled(id: "ianir_kabbalat_chabbat", rawRes: "ianir_kabbalat_chabbat", titleRes: "track_ianir_kabbalat_chabbat"),
        Bundled(id: "ianir_bessarabie", rawRes: "ianir_bessarabie", titleRes: "track_ianir_bessarabie"),
    ]
}
