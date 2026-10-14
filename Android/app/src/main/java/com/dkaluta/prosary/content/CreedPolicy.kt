package com.dkaluta.prosary.content

import kotlinx.serialization.Serializable

/** An authored source decides its Creed usage; app/interface settings never override it. */
@Serializable
data class CreedPolicy(val apostlesCreed: Boolean = true, val filioque: String? = null, val rite: String? = null)
