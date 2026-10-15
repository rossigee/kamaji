// Copyright 2022 Clastix Labs
// SPDX-License-Identifier: Apache-2.0

package utils

import (
	"github.com/clastix/kamaji/api/v1alpha1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

func IsPaused(obj client.Object) bool {
	if obj.GetAnnotations() == nil {
		return false
	}
	_, paused := obj.GetAnnotations()[v1alpha1.PausedReconciliationAnnotation]

	return paused
}
