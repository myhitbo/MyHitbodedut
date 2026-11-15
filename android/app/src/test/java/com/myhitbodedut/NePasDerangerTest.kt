package com.myhitbodedut

import android.app.NotificationManager
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * « Ne pas déranger » pendant la séance (13/11, audit FSEANCE-01, FBARRIERE-03) :
 * posé seulement sur un téléphone où rien n'est réglé, pour que « rétablir » soit
 * toujours « tout passe ».
 */
class NePasDerangerTest {

    @Test
    fun `le mode n est pose que si tout passe encore`() {
        assertTrue(NePasDeranger.doitActiver(NotificationManager.INTERRUPTION_FILTER_ALL))
    }

    @Test
    fun `un mode deja regle par l utilisateur n est pas touche`() {
        listOf(
            NotificationManager.INTERRUPTION_FILTER_PRIORITY,
            NotificationManager.INTERRUPTION_FILTER_ALARMS,
            NotificationManager.INTERRUPTION_FILTER_NONE,
            NotificationManager.INTERRUPTION_FILTER_UNKNOWN,
        ).forEach { assertFalse("filtre $it", NePasDeranger.doitActiver(it)) }
    }

    /** Une seance sans duree oubliee atteint le plafond : le service peut la clore. */
    @Test
    fun `une seance ouverte oubliee est echue au plafond`() {
        val debut = 1_000_000L
        assertFalse(SessionRule.estEchue(debut, 0L, SessionRule.OUVERTE, debut + (SessionRule.PLAFOND_OUVERTE - 1) * 60_000L))
        assertTrue(SessionRule.estEchue(debut, 0L, SessionRule.OUVERTE, debut + SessionRule.PLAFOND_OUVERTE * 60_000L))
    }
}
