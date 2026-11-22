package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** « Je ne sais pas quoi dire » et « Commencer simplement » (propositions 3 et 15, 19/10). */
class QuestionsBlocageTest {

    @Test
    fun `dix questions, une a la fois, puis on recommence`() {
        assertEquals(10, QuestionsBlocage.QUESTIONS.size)
        assertEquals(0, QuestionsBlocage.suivante(-1))
        assertEquals(1, QuestionsBlocage.suivante(0))
        assertEquals(0, QuestionsBlocage.suivante(9))
    }

    @Test
    fun `les questions et les quatre entrees existent dans les trois langues et les deux orientations`() {
        val cles = listOf("question_merci", "question_fin", "question_suivante", "question_rang",
            "simplement_parler", "simplement_ecrire", "simplement_prier", "simplement_question")
        listOf("values", "values-en", "values-iw").forEach { d ->
            val xml = File("src/main/res/$d/strings.xml").readText()
            cles.forEach { assertTrue("$d : $it", xml.contains("name=\"$it\"")) }
        }
        listOf("layout", "layout-land").forEach { d ->
            val xml = File("src/main/res/$d/activity_session.xml").readText()
            listOf("session_questions", "session_question_suivante", "session_simplement", "simplement_question")
                .forEach { assertTrue("$d : $it", xml.contains("@+id/$it")) }
        }
    }

    /**
     * Recette du 22/11 : sur un écran de 411 dp, « Une question » se coupait au milieu du mot
     * (« Une questi / on ») ; couchée sur une tablette, chaque mot l'était (« Par / ler »).
     * Debout : une marge intérieure de 4 dp et une part plus large aux deux mots les plus longs.
     * Couchée, où la colonne est étroite : deux rangées de deux.
     */
    @Test
    fun `les quatre entrees ont la place de leur mot`() {
        val entrees = listOf("simplement_parler", "simplement_ecrire", "simplement_prier", "simplement_question")
        fun bouton(xml: String, id: String) = xml.substringAfter("@+id/$id\"").substringBefore("/>")
        listOf("layout", "layout-land").forEach { d ->
            val xml = File("src/main/res/$d/activity_session.xml").readText()
            entrees.forEach { id ->
                val b = bouton(xml, id)
                assertTrue("$d : $id, marge de 4 dp", b.contains("android:paddingStart=\"4dp\"") && b.contains("android:paddingEnd=\"4dp\""))
                assertTrue("$d : $id, largeur minimale", b.contains("android:minWidth=\"0dp\""))
            }
        }
        val debout = File("src/main/res/layout/activity_session.xml").readText()
        assertTrue("debout : la part de « Écrire »", bouton(debout, "simplement_ecrire").contains("android:layout_weight=\"1.15\""))
        assertTrue("debout : la part de « Une question »", bouton(debout, "simplement_question").contains("android:layout_weight=\"1.45\""))
        val couchee = File("src/main/res/layout-land/activity_session.xml").readText()
            .substringAfter("@+id/session_simplement\"")
        assertTrue("couchée : les rangées s'empilent", couchee.substringBefore("<LinearLayout").contains("android:orientation=\"vertical\""))
        val rangees = couchee.split("android:orientation=\"horizontal\"")
        assertEquals("couchée : deux rangées", 3, rangees.size)
        assertTrue("couchée : Parler et Écrire ensemble", rangees[1].contains("simplement_parler") && rangees[1].contains("simplement_ecrire"))
        assertTrue("couchée : Prier et Une question ensemble", rangees[2].contains("simplement_prier") && rangees[2].contains("simplement_question"))
    }
}
