extends RefCounted


static func sync(model: Node3D, rig: Dictionary) -> void:
	if not rig.has("skeleton"): return
	var skeleton: Skeleton3D = rig.skeleton
	var model_inverse = model.global_transform.affine_inverse()
	var to_skin = (model_inverse * skeleton.global_transform).affine_inverse()
	var frames: Array = rig.frames
	for link in rig.links:
		var normalized: Transform3D = model_inverse * link.node.global_transform
		var target = to_skin * Transform3D(normalized.basis * link.neutral_basis, normalized.origin)
		frames[link.index] = target
		var local = frames[link.parent].affine_inverse() * target if link.parent >= 0 else target


		var pose: Transform3D = local
		skeleton.set_bone_pose_position(link.index, pose.origin)
		skeleton.set_bone_pose_rotation(link.index, pose.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(link.index, pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
